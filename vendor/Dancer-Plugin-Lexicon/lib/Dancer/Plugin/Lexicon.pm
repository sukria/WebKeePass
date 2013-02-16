package Dancer::Plugin::Lexicon;

use strict;
use warnings;
use Dancer::Plugin;

use Package::Stash();
use Dancer ':syntax';
use File::Spec::Functions qw(rel2abs);

use I18N::LangTags qw(implicate_supers panic_languages);
use I18N::LangTags::Detect;
use I18N::LangTags::List;

my $Handle = __PACKAGE__ . ' - handle';

my %Exports = (
    'set_language'    => \&_external_set_language,
    'language'        => \&_current_language,
    'language_tag'    => \&_language_tag,
    'installed_langs' => \&_installed_langs,
    'localize'        => \&_localize,
);

for my $k ( keys %Exports ) {
    register( $k => sub { $Exports{$k}->(@_) } );
}

    _setup_i18n();
#===================================
no warnings 'redefine';
sub import {
#===================================
    # This import is only needed for Dancer 1
    return if int(dancer_version) > 1;

    _setup_i18n();

    __PACKAGE__->export_to_level( 1, @_ );
}


sub _before_hook {
    my $settings = _setup_i18n();
    my $session_name = $settings->{session_name} || 'lang';

    my $lang = param( $settings->{param_name} || "lang" )
      || eval { session $session_name};

    my @langs;
    if ($lang) {
        @langs = $lang;
    }
    elsif ( $settings->{auto_detect} ) {
        @langs =
          I18N::LangTags::Detect::http_accept_langs( request->accept_language );
        @langs = implicate_supers(@langs);
        push @langs, panic_languages(@langs);
    }

    $lang = _set_language(@langs)->language_tag;

    eval { session $session_name => $lang };
}

sub _before_template_render_hook {
    my $tokens = shift;

    # get the name of the localize methods in settings
    my $funcs = plugin_setting->{'func'} || ['loc'];
    $funcs = [$funcs] unless ref $funcs eq 'ARRAY';

    # add them in the tokens
    $tokens->{$_} = sub { _get_handle()->maketext(@_) } for @{$funcs};

    return $tokens;
}

if ( int(dancer_version) == 1 ) {
    hook before          => sub { _before_hook(@_) };
    hook before_template => sub { _before_template_render_hook(@_) };
}
else {
    register dp_lexicon_install_hooks => sub {
        my $dsl = shift;

        $dsl->hook( 
            before => \&_before_hook
        );

        $dsl->hook(
            before_template_render => \&_before_template_render_hook
        );
      };
}

#===================================
sub _get_handle       { var $Handle or _set_language() }
sub _language_tag     { _get_handle->language_tag }
sub _installed_langs  { _setup_i18n()->{langs} }
sub _current_language { _installed_langs()->{ _language_tag() } }
sub _localize         { 
    my ($dsl, @args) = plugin_args(@_); 
    _get_handle->maketext(@args) 
}
#===================================

#===================================
sub _localize_ {
#===================================
    return \*_ unless @_;
    _localize(@_);
}

#===================================
sub _set_language {
#===================================
    my $settings = _setup_i18n();
    my $handle
        = $settings->{namespace}->get_handle( @_, $settings->{default} );
    var $Handle => $handle;
}

#===================================
sub _external_set_language {
#===================================
    my ($dsl, @args) = plugin_args(@_);
    _set_language(@args);
    _current_language;
}

#===================================
sub _setup_i18n {
#===================================
    my $appdir = setting('appdir') or return;
    
    my $settings = plugin_setting();
    return $settings if $settings->{_loaded};

    $settings->{auto_detect} = 1
        unless exists $settings->{auto_detect};

    my $default = $settings->{default}
        || 'en';

    my $base_class = _load_base_class( $settings->{namespace}, $default );
    my $path = rel2abs( ( $settings->{path} || 'languages' ), $appdir );

    my %langs;
    my $to_load = $settings->{langs};
    my %not_loaded = ( $default => 1, %{ $to_load || {} } );

    opendir my ($dir), $path
        or die "Couldn't read directory ($path) : $!";

    foreach my $entry ( readdir $dir ) {
        next unless $entry =~ m/\A (\w+)\.(?:po|mo) \z/xms;
        my $tag = my $lang = $1;
        $tag =~ s/_/-/g;
        if ($to_load) {
            $langs{$tag} = $to_load->{$lang} || $to_load->{$tag} || next;
        }
        else {
            $langs{$tag} = I18N::LangTags::List::name($tag);
        }
        delete @not_loaded{ $tag, $lang };
        my $is_default = $lang eq $default || $tag eq $default;
        _load_lang( path( $path, $entry ), $base_class, $lang, $is_default );
    }

    closedir $dir;

    if (%not_loaded) {
        die "Couldn't find the .po or .mo in $path for: "
            . join( ', ', sort keys %not_loaded );
    }

    $settings->{langs}   = \%langs;
    $settings->{_loaded} = 1;
    _setup_funcs($settings);
    return $settings;
}

#===================================
sub _setup_funcs {
#===================================
    my $settings = shift;
    my $funcs = $settings->{func} || ['loc'];
    $funcs = [$funcs] unless ref $funcs eq 'ARRAY';
    my %localizers
        = map { $_ => $_ eq '_' ? \&_localize_ : \&_localize } @$funcs;

    &register( $_, $localizers{$_} ) for keys %localizers;
    $settings->{exports} = { %Exports, %localizers };

}

#===================================
sub _load_base_class {
#===================================
    my ( $base_class, $default ) = @_;
    die "Missing (namespace) param in I18N config" 
        unless $base_class;

    for my $package ( 'Locale::Maketext', 'Locale::Maketext::Lexicon' ) {
        eval "use $package";
        die "$package is not installed : $@" if $@;
    }
    _load_if_exists($base_class);

    {
        no strict 'refs';
        push @{ $base_class . '::ISA' }, 'Locale::Maketext'
            unless $base_class->isa('Locale::Maketext');
    }
    my $setup = '';
    my $stash = Package::Stash->new($base_class);
    unless ( $stash->has_symbol('&init') ) {
        $setup = <<'';
        sub init {
            my $lh = shift;
            $lh->SUPER::init();
            $lh->fail_with('failure_handler_auto');
            return $lh;
        };

    }
    unless ( $stash->has_symbol('&fallback_languages') ) {
        $setup .= "sub fallback_languages { '$default' }";
    }

    if ($setup) {
        eval "package $base_class; $setup;1;"
            or die "Setting up $base_class: $@";
    }

    return $base_class;
}

#===================================
sub _load_lang {
#===================================
    my ( $path, $base_class, $lang, $is_default ) = @_;

    my $class = $base_class . '::' . $lang;
    _load_if_exists($class);

    unless ( $class->isa($base_class) ) {
        no strict 'refs';
        push @{ $class . '::ISA' }, $base_class;
    }

    $path =~ s/\\/\\\\/g;
    $path =~ s/'/\\'/g;

    my $make_auto
        = $is_default
        ? q(  our %Lexicon; $Lexicon{_AUTO} = 1;)
        : '';

    my $loader = <<"LOADER";
        package $class;
        use Locale::Maketext::Lexicon(
            Gettext => '$path',
            _decode => 1,
        );
        $make_auto
        1;
LOADER

    eval $loader or die "Loading ($path) : $@";

    return $class;
}

#===================================
sub _load_if_exists {
#===================================
    my $class = shift;
    eval "use $class";
    return 0 if $@ && $@ =~ /Can't locate/;
    return 1 if !$@;

    die "Unable to load $class : $@";
}

register_plugin for_versions => [1, 2];

1;
__END__

# ABSTRACT: Flexible I18N using Locale::Maketext::Lexicon for Dancer apps

=head1 SYNOPSIS

=head2 A language specific sub-class

    package MyApp::Lexicon::pl;

    sub quant {
        # Override default plural handling to cope
        # with the Polish form of plurals, ie:
        # 1   -> single
        # 2-4 -> "few"
        # 5-  -> plural
    }

=head2 Config file

    plugins:
        Lexicon:
            namespace:      MyApp::Lexicon
            path:           languages
            auto_detect:    1
            default:        en
            func:           [l, _]
            session_name:   lang
            param_name:     lang
            langs:
                  en:       "English"
                  en-us:    "US English"
                  da:       "Dansk"
                  de:       "Deutsch"
                  pl:       "Polish"

=head2 In your code

    package MyApp::Handler;

    use Dancer qw(:syntax);
    use Dancer::Plugin::Lexicon;

    print language;
    # English

    print language_tag;
    # en

    my $installed = installed_langs;
    my $number    = keys %$installed;

    print _('I know [quant,_1,language,languages]', $number);
    # I know 5 languages

    print set_language('fr','de_DE','en');
    # Deutsch


    get '/' => sub {
        debug "Auto-detected language is ".language;

    };

=head1 DESCRIPTION

L<Dancer::Plugin::Lexicon> uses L<Locale::Maketext::Lexicon> to provide
I18N functionality to your Dancer application.

Translations are stored in PO or MO (compiled PO) gettext files in the
C<languages/> dir. You can generate or update your PO files by automatically
extracting translatable strings from your code and templates with
L<xgettext.pl>.

It allows you to add language sub-classes which can handle grammatical
differences in that language (such as the Polish example given in the
L</SYNOPSIS>).

The user's preferred language can be auto-detected from their browser
settings, and the current language is automatically stored in the user's
session.  Including C<lang=$lang_tag> in the query string change the
user's language.

=head1 CONFIGURATION

=head2 namespace

The only required configuration is C<namespace>, which should be the base
class in your application that you will use for I18N.  The class itself
doesn't have to exist, but will be loaded if it does exist:

    plugins:
        Lexicon:
            namespace:  MyApp::Lexicon

See L<LANGUAGE SUB-CLASSES> for more.

=head2 path

The C<path> option (default C<languages/>) allows you to set a different
path for where to find your PO files.

=head2 default

The default language to use.  If not specifified, it defaults to C<en>. The
language must exist in your C<languages/> directory. If a translation doesn't
exist in the current language, it will be translated using the default language
instead.

=head2 langs

If not specified, then any PO files in your C<languages/> directory will be
loaded.

Alternatively, you can specify a list of language tags:

    langs:
        en
        en_US
        pt
        pt_BR

The name of each language will be derived from L<I18N::LangTags::List/name>
which provides the name in English.

You can provide your own names as follows:

    langs:
        en:     English
        en_US:  US English
        de:     Deutsch
        it:     Italiano

A PO file must exist for all listed languages.

=head2 func

One or more function names which will be exported to your modules and templates
to localize  text.  For instance:

    func:   x

Would allow you to do:

    x('Localize me')

And:

    func:   [l, _]

Would allow you to do:

    _('Localize me');
    l('Localize me');

=head2 session_name

The C<session_name> param (default C<"lang">) is the session key used to
store the user's current language (if sessions are available).

=head2 param_name

The C<param_name> param (default C<"lang">) is the query string parameter used
to change the user's current language.

=head2 auto_detect

If you don't want L<Dancer::Plugin::Lexicon> to automatically detect the
user's preferred language from their browser headers, then set:

    auto_detect: 0

=head2 DANCER 2 COMPATIBILITY

This plugin works fine under Dancer 2 as long as you use the following keyword:

    dp_lexicon_install_hooks();

This will install the hooks in your application properly.

That's the only change needed when upgrading your application to Dancer2 with
this plugin.

=head1 FUNCTIONS

=head2 set_language

C<set_language()>  accepts a list of language tags, and chooses the best
matching available language.  For instance, if you have these languages
available: C<'en_GB','fr'>:

    set_language('en_US','en_AU');
    # British English

    set_language('it','de');
    # French (closer to Italian)

If no suitable language is found, then it will set the default language, which
you can also force with:

    set_language;

=head2 language

The name of the current language as specified in L</installed_langs>.

=head2 language_tag

The language tag of the current language.

=head2 installed_langs

A hashref containing all installed languages.  The keys are language tags,
and the values are the names as specified in your config, or as derived
from L<I18N::LangTags::List/name>.

=head2 localize

The C<localize> function will translate the passed in phrase using the
current language:

    localize('Translate me', @any_args);

Also, and functions that you specify in C</func> will also be exported as
aliases of L</localize>

=head1 LANGUAGE SUB-CLASSES

No C<.pm> files need to exist, but if they do exist, they will be loaded
and setup correctly.

For instance, the class specified in L</namespace> (eg C<MyClass::Lexicon>) is
loaded or inflated, and setup to inherit from L<Locale::Maketext>.
If you load C<fr.po> then it tries to load C<MyClass::Lexicon::fr> if it exists,
otherwise it inflates it.  This class inherits from L<MyClass::Lexicon>.

If you want to override any functionality for a particular language, then
you can create the file C<lib/MyClass/Lexicon/fr.pm> and add your overrides
in there.

Also, you could have (eg) C<MyClass::Lexicon::pt_br> (Brazilian Portuguese),
which is a subclass of C<MyClass::Lexicon::pt> (Portuguese). Any translations
that aren't found in C<pt_br.po> will be looked for in C<pt.po>, before finally
failing over to the default language.


=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc Dancer::Plugin::Lexicon

You can also look for information at:

=over

=item * GitHub

L<http://github.com/clintongormley/Dancer-Plugin-Lexicon>

=item * CPAN Ratings

L<http://cpanratings.perl.org/d/Dancer-Plugin-Lexicon>

=item * Search MetaCPAN

L<https://metacpan.org/module/Dancer::Plugin::Lexicon>

=back


