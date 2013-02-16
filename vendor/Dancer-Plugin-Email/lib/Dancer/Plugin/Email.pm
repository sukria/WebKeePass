package Dancer::Plugin::Email;

use Dancer ':syntax';
use Dancer::Plugin;
use Email::Sender::Simple 'sendmail';
use File::Type;
use MIME::Entity;
use Module::Load 'load';
use Try::Tiny;

register email => sub {
    my ($dsl, $params) = plugin_args(@_);
    $params ||= {};

    my $extra_headers = delete($params->{headers}) || {};
    my $conf = plugin_setting;

    my $conf_headers = $conf->{headers} || {};
    my %headers = ( %$conf_headers, %$params, %$extra_headers );
    my $attach = $headers{attach};
    if (my $type = $headers{type}) {
        $headers{Type} = $type eq 'html' ? 'text/html' : 'text/plain';
    }
    $headers{Type}   ||= 'text/plain';
    $headers{Format} ||= 'flowed' if $headers{Type} eq 'text/plain';
    delete $headers{$_} for qw(body message attach type);

    my $email = MIME::Entity->build(
        Charset  => 'utf-8',
        Encoding => 'quoted-printable',
        %headers, # %headers may overwrite type, charset, and encoding
        Data => $params->{body} || $params->{message},
    );
    if ($attach) {
        my @attachments = ref($attach) eq 'ARRAY' ? @$attach : $attach;
        for my $attachment (@attachments) {
            $email->attach(
                Path     => $attachment,
                Type     => File::Type->mime_type($attachment),
                Encoding => 'base64',
            );
        }
    }

    my $transport;
    my $conf_transport = $conf->{transport} || {};
    if (my ($transport_name) = keys %$conf_transport) {
        my $transport_params = $conf_transport->{$transport_name} || {};
        my $transport_class = "Email::Sender::Transport::$transport_name";
        my $transport_redirect = $transport_params->{redirect_address} || '';
        load $transport_class;
        $transport = $transport_class->new($transport_params);

        if ($transport_redirect) {
            $transport_class = 'Email::Sender::Transport::Redirect';
            load $transport_class;
            debug "Redirecting email to $transport_redirect.";
            $transport = $transport_class->new(
                transport        => $transport,
                redirect_address => $transport_redirect
            );
        }
    }
    return sendmail $email, { transport => $transport };
};


register_plugin for_versions => [1, 2];

# ABSTRACT: Simple email sending for Dancer applications

=head1 SYNOPSIS

    use Dancer;
    use Dancer::Plugin::Email;
    
    post '/contact' => sub {
        email {
            from    => 'bob@foo.com',
            to      => 'sue@foo.com',
            subject => 'allo',
            body    => 'Dear Sue, ...',
            attach  => '/path/to/attachment',
        };
    };
    
=head1 DESCRIPTION

This plugin tries to make sending emails from L<Dancer> applications as simple
as possible.
It uses L<Email::Sender> under the hood.
In a lot of cases, no configuration is required.
For example, if your app is hosted on a unix-like server with sendmail
installed, calling C<email()> will just do the right thing.

IMPORTANT: Version 1.x of this module is not backwards compatible with the
0.x versions.
This module was originally built on Email::Stuff which was built on
Email::Send which has been deprecated in favor of Email::Sender.
Versions 1.x and on have be refactored to use Email::Sender.
I have tried to keep the interface the same as much as possible.
The main difference is the configuration.
If there are features missing that you were using in older versions,
then please let me know by creating an issue on 
L<github|https://github.com/ironcamel/Dancer-Plugin-Email>.

=head1 FUNCTIONS

This module by default exports the single function C<email>.

=head2 email

This function sends an email.
It takes a single argument, a hashref of parameters.
Default values for the parameters may be provided in the headers section of
the L</CONFIGURATION>.
Paramaters provided to this function will override the corresponding
configuration values if there is any overlap.
An exception is thrown if sending the email fails,
so wrapping calls to C<email> with try/catch is recommended.

    use Dancer;
    use Dancer::Plugin::Email;
    use Try::Tiny;

    post '/contact' => sub {
        try {
            email {
                from    => 'bob@foo.com',
                to      => 'sue@foo.com, jane@foo.com',
                subject => 'allo',
                body    => 'Dear Sue, ...',
                attach  => ['/path/to/attachment1', '/path/to/attachment2'],
                type    => 'html', # can be 'html' or 'plain'
                # Optional extra headers
                headers => {
                    "X-Mailer"          => 'This fine Dancer application',
                    "X-Accept-Language" => 'en',
                }
            };
        } catch {
            error "Could not send email: $_";
        };
    };
    
=head1 CONFIGURATION

No configuration is necessarily required.
L<Email::Sender::Simple> tries to make a good guess about how to send the
message.
It will usually try to use the sendmail program on unix-like systems
and SMTP on Windows.
However, you may explicitly configure a transport in your configuration.
Only one transport may be configured.
For documentation for the parameters of the transport, see the corresponding
Email::Sender::Transport::* module.
For example, the parameters available for the SMTP transport are documented
here L<Email::Sender::Transport::SMTP/ATTRIBUTES>.

You may also provide default headers in the configuration:

    plugins:
      Email:
        # Set default headers (OPTIONAL)
        headers:
          from: 'bob@foo.com'
          subject: 'default subject'
          X-Mailer: 'MyDancer 1.0'
          X-Accept-Language: 'en'
        # Explicity set a transport (OPTIONAL)
        transport:
          Sendmail:
            sendmail: '/usr/sbin/sendmail'
        
Example configuration for sending mail via Gmail:

    plugins:
      Email:
        transport:
          SMTP:
            ssl: 1
            host: 'smtp.gmail.com'
            port: 465
            sasl_username: 'bob@gmail.com'
            sasl_password: 'secret'

Use the Sendmail transport using the sendmail program in the system path:

    plugins:
      Email:
        transport:
          Sendmail:

Use the Sendmail transport with an explicit path to the sendmail program:

    plugins:
      Email:
        transport:
          Sendmail:
            sendmail: '/usr/sbin/sendmail'

=head1 COMPATIBILITY

This plugin is compatible with both Dancer 1 and 2.

=head1 SEE ALSO

=over

=item L<Email::Sender>

=back

=cut

1;
