package Data::MuForm::Localizer;
# ABSTRACT: Localizer
use Moo;

use Types::Standard -types;

=head1 NAME

Data::MuForm::Localizer

=head1 DESCRIPTION

Localizer for Data::MuForm

This code has mainly been borrowed from Locale::TextDomain::OO.
It requires UTF-8 and handles only .po files. It does not use
the various LOCALE flags for languages. Language must be set
on creation of the form. It does handle plurals.

TODO: implement allowing specification of user-provided messages
file, and merging two message files

=cut

has 'language' => ( is => 'rw', builder => 'build_language' );
sub build_language { 'en' }

has 'messages_directory' => ( is => 'rw' );

sub loc_ {
  my ($self, $msgid) = @_;
  #   translate($self, $msgctxt, $msgid, $msgid_plural, $count, $is_n)
  return $self->translate(undef, $msgid);
}

sub loc_x {
  my ($self, $msgid, %args) = @_;
  #   translate($self, $msgctxt, $msgid, $msgid_plural, $count, $is_n)
  my $msg = $self->translate(undef, $msgid);
  my $out = $self->expand_named( $msg, %args );
  return $out;
}

sub loc_nx {
  my ($self, $msgid, $msgid_plural, $count, %args) = @_;
  #   translate($self, $msgctxt, $msgid, $msgid_plural, $count, $is_n)
  my $msg = $self->translate(undef, $msgid, $msgid_plural, $count, 1);
  my $out = $self->expand_named( $msg, %args );
  return $out;
}

=cut

sub loc_px {
  my ($self, $msgid, %args) = @_;

  return $msgid;
}
=cut

sub loc_npx {
  my ($self, $msgctxt, $msgid, $msgid_plural, $count, %args) = @_;
  #   my ($self, $msgctxt, $msgid, $msgid_plural, $count, @args) = @_;
  my $msg = $self->translate($msgctxt, $msgid, $msgid_plural, $count, 1);
  my $out = $self->expand_named( $msg, %args );
  return $out;
}

our $lexicons = {
};

sub get_lexicon {
  my $self = shift;
  my $lang = $self->language;
  if ( ! exists $lexicons->{$lang} ) {
    $lexicons->{$lang} = $self->load_lexicon($lang);
  }
  return $lexicons->{$lang};
}

sub load_lexicon {
  my ( $self, $lang ) = @_;

  # $lang is interpolated into the catalog filename below, so it has to
  # be a bare locale tag.  Anything else, in particular a value holding
  # '/' or '..' segments, would load a catalog from outside the messages
  # directory.  Returning undef here is what a locale with no catalog
  # already does: the message falls back to the msgid.
  return undef
    if ! defined $lang || $lang !~ m{\A[A-Za-z0-9_.\-]+\z};

  my $file = $self->module_path;
  $file =~ s/Localizer.pm//;
  $file .= "Messages/$lang.po";
  my $lexicon = $self->load_file($file);
  return $lexicon;
}

sub load_file {
  my ( $self, $file ) = @_;

    open(IN, "<:encoding(UTF-8)", $file)
        or return undef;

    my @entries;
    my %entries;
    my $index;
    my $po;
    my %buffer;
    my $last_buffer;
    my $line_number = 0;
    while (<IN>) {
        chomp;
        $line_number++;

        # Strip trailing \r\n chars
        s{[\r\n]*$}{};

        if (/^$/) {

            # Empty line. End of an entry.

            if (defined($po)) {
                $po->{fuzzy_msgctxt} = $buffer{fuzzy_msgctxt}
                    if defined $buffer{fuzzy_msgctxt};
                $po->{fuzzy_msgid} = $buffer{fuzzy_msgid} if defined $buffer{fuzzy_msgid};
                $po->{fuzzy_msgid_plural} = $buffer{fuzzy_msgid_plural}
                    if defined $buffer{fuzzy_msgid_plural};
                $po->{msgctxt} = $buffer{msgctxt}        if defined $buffer{msgctxt};
                $po->{msgid} = $buffer{msgid}            if defined $buffer{msgid};
                $po->{msgid_plural} = $buffer{msgid_plural} if defined $buffer{msgid_plural};
                $po->{msgstr} = $buffer{msgstr}          if defined $buffer{msgstr};
                $po->{msgstr_n} = $buffer{msgstr_n}      if defined $buffer{msgstr_n};

                # Save this message
                $entries{$po->{msgid}} = $po;
                push @entries, $po;
                my $index_key = join_message_key( msgid => $po->{msgid}, msgstr => $po->{msgstr}, msgctxt => $po->{msgctxt});
                $index->{$index_key} = $po;

                $po = undef;
                $last_buffer = undef;
                %buffer = ();
            }
        }
        elsif (/^#\s+(.*)/ or /^#()$/) {

            # Translator comments
            $po = { line_number => $line_number } unless defined($po);
            if (defined($po->{comment})) {
                $po->{comment} = $po->{comment} . "\n$1";
            }
            else {
                $po->{comment} = $1;
            }
        }
        elsif (/^#\.\s*(.*)/) {

            # Automatic comments
            $po = { line_number => $line_number } unless defined($po);
            if (defined($po->{automatic})) {
                $po->{automatic} = $po->automatic . "\n$1";
            }
            else {
                $po->{automatic} = $1;
            }
        }
        elsif (/^#:\s+(.*)/) {

            # reference
            $po = { line_number => $line_number } unless defined($po);
            if (defined($po->{reference})) {
                $po->{reference} = $po->reference . "\n$1";
            }
            else {
                $po->{reference} = $1;
            }
        }
        elsif (/^#,\s+(.*)/) {

            # flags
            my @flags = split /\s*[,]\s*/, $1;
#           $po = { line_number => $line_number } unless defined($po);
#           foreach my $flag (@flags) {
#               $po->add_flag($flag);
#           }
        }
        elsif (/^#(~)?\|\s+msgctxt\s+(.*)/) {
            $po = { line_number => $line_number } unless defined($po);
            $buffer{fuzzy_msgctxt} = $self->dequote($2);
            $last_buffer = \$buffer{fuzzy_msgctxt};
            $po->{obsolete} = 1 if $1;
        }
        elsif (/^#(~)?\|\s+msgid\s+(.*)/) {
            $po = { line_number => $line_number } unless defined($po);
            $buffer{fuzzy_msgid} = $self->dequote($2);
            $last_buffer = \$buffer{fuzzy_msgid};
            $po->{obsolete} = 1 if $1;
        }
        elsif (/^#(~)?\|\s+msgid_plural\s+(.*)/) {
            $po = { line_number => $line_number } unless defined($po);
            $buffer{fuzzy_msgid_plural} = $self->dequote($2);
            $last_buffer = \$buffer{fuzzy_msgid_plural};
            $po->{obsolete} = 1 if $1;
        }
        elsif (/^(#~\s+)?msgctxt\s+(.*)/) {
            $po = { line_number => $line_number } unless defined($po);
            $buffer{msgctxt} = $self->dequote($2);
            $last_buffer = \$buffer{msgctxt};
            $po->obsolete(1) if $1;
        }
        elsif (/^(#~\s+)?msgid\s+(.*)/) {
            $po = { line_number => $line_number } unless defined($po);
            $buffer{msgid} = $self->dequote($2);
            $last_buffer = \$buffer{msgid};
            $po->obsolete(1) if $1;
        }
        elsif (/^(#~\s+)?msgid_plural\s+(.*)/) {
            $po = { line_number => $line_number } unless defined($po);
            $buffer{msgid_plural} = $self->dequote($2);
            $last_buffer = \$buffer{msgid_plural};
            $po->obsolete(1) if $1;
        }
        elsif (/^(?:#~\s+)?msgstr\s+(.*)/) {

            # translated string
            $buffer{msgstr} = $self->dequote($1);
            $last_buffer = \$buffer{msgstr};
        }
        elsif (/^(?:#~\s+)?msgstr\[(\d+)\]\s+(.*)/) {

            # translated string
            $buffer{msgstr_n}{$1} = $self->dequote($2);
            $last_buffer = \$buffer{msgstr_n}{$1};
        }
        elsif (/^(?:#(?:~|~\||\|)\s+)?(".*)/) {

            # continued string. Accounts for:
            #   normal          : "string"
            #   obsolete        : #~ "string"
            #   fuzzy           : #| "string"
            #   fuzzy+obsolete  : #~| "string"
            $$last_buffer .= $self->dequote($1);
        }
        else {
            warn "Strange line at $file line $line_number: [$_]\n";
        }
    }
    if (defined($po)) {

        $po->{msgctxt} = $buffer{msgctxt}
            if defined $buffer{msgctxt};
        $po->{msgid} = $buffer{msgid}
            if defined $buffer{msgid};
        $po->{msgid_plural} = $buffer{msgid_plural}
            if defined $buffer{msgid_plural};
        $po->{msgstr} = $buffer{msgstr}
            if defined $buffer{msgstr};
        $po->{msgstr_n} = $buffer{msgstr_n}
            if defined $buffer{msgstr_n};

        # save messages
        $entries{$po->{msgid}} = $po;
        push @entries, $po;
        my $index_key = join_message_key( msgid => $po->{msgid}, msgstr => $po->{msgstr}, msgctxt => $po->{msgctxt});
        $index->{$index_key} = $po;

    }
    close IN;

    # the first entry is the header. Extract information from the header msgstr
    my $header_ref = $entries[0];
    %{$header_ref} = (
        msgid => $header_ref->{msgid},
        %{ $self->extract_header_msgstr( $header_ref->{msgstr} ) },
    );

    return $index;
}

sub dequote {
    my ( $self, $string ) = @_;

    return undef
        unless defined $string;

    $string =~ s/^"(.*)"/$1/;
    $string =~ s/\\"/"/g;
    $string =~ s/(?<!(\\))\\n/\n/g;        # newline
    $string =~ s/(?<!(\\))\\{2}n/\\n/g;    # inline newline
    $string =~ s/(?<!(\\))\\{3}n/\\\n/g;   # \ followed by newline
    $string =~ s/\\{4}n/\\\\n/g;           # \ followed by inline newline
    $string =~ s/\\\\(?!n)/\\/g;           # all slashes not related to a newline
    return $string;
}

sub expand_named {
    my ($self, $text, @args) = @_;

    defined $text
        or return $text;
    my $arg_ref = @args == 1
        ? $args[0]
        : {
            @args % 2
            ? die 'MuForm error Arguments expected pairwise'
            : @args
        };

    my $regex = join q{|}, map { quotemeta $_ } keys %{$arg_ref};

    $text =~ s{
        (
            \{
            ( $regex )
            (?: [ ]* [:] ( [^\}]+ ) )?
            \}
        )
    }
    {
        $self->_mangle_value($1, $arg_ref->{$2}, $3)
    }xmsge;
    ## use critic (EscapedMetacharacters)

    return $text;
}

sub _mangle_value {
    my ($self, $placeholder, $value, $attribute) = @_;

    defined $value
        or return q{};
    defined $attribute
        or return $value;
    return $value;
}


sub translate {
    my ($self, $msgctxt, $msgid, $msgid_plural, $count, $is_n) = @_;

    my $lexicon = $self->get_lexicon;

    my $msg_key = join_message_key(
        msgctxt      => $msgctxt,
        msgid        => $msgid,
        msgid_plural => $msgid_plural,
    );

    if ( $is_n ) {
        my $plural_code = $lexicon->{ q{} }->{plural_code}
            or die qq{Plural-Forms not found in lexicon};
        my $multiplural_index = ref $count eq 'ARRAY'
            ? $self->_calculate_multiplural_index($count, $plural_code, $lexicon )
            : $plural_code->($count);
        my $msgstr_plural = exists $lexicon->{$msg_key}
            ? $lexicon->{$msg_key}->{msgstr_plural}->[$multiplural_index] : ();
        if ( ! defined $msgstr_plural ) { # fallback
            $msgstr_plural = $plural_code->($count)
                ? $msgid_plural
                : $msgid;
        }
        return $msgstr_plural;
    }

    my $msgstr = exists $lexicon->{$msg_key}
        ? $lexicon->{$msg_key}->{msgstr}
        : ();
    if ( ! defined $msgstr ) { # fallback
        $msgstr = $msgid;
    }

    return $msgstr;
}

sub length_or_empty_list {
    my $thing = shift;
    defined $thing or return;
    length $thing or return;
    return $thing;
}

sub _calculate_multiplural_index {
    my ($self, $count_ref, $plural_code, $lexicon) = @_;

    my $nplurals = $lexicon->{ q{} }->{multiplural_nplurals}
        or die qq{X-Multiplural-Nplurals not found in lexicon"};
    my @counts = @{$count_ref}
        or die 'Count array is empty';
    my $index = 0;
    while (@counts) {
        $index *= $nplurals;
        my $count = shift @counts;
        $index += $plural_code->($count);
    }

    return $index;
}

sub join_message_key {
    my ( %args ) = @_;

    my $key = join( '{MSG}',
        (
            join( '{PL}',
                length_or_empty_list( $args{msgid} ),
                length_or_empty_list( $args{msgid_plural} ),
            )
        ),
        length_or_empty_list( $args{msgctxt} )
    );
}

#====== Header Extract =======

# The Plural-Forms expression from the catalog reaches a string eval, so
# it has to be checked before it is used.  A character allowlist is not
# enough: **, //, ++ and <> are Perl operators spelled with the same
# characters the gettext plural operators use.  The header is therefore
# tokenized and parsed against the gettext plural grammar (gettext's
# plural.y: the variable n, unsigned integers, the conditional and the C
# integer operators, nothing else), and the code that is evaluated is
# generated from the accepted tokens rather than from the header text.

# Longest match first, so that <= is one token and not < followed by =.
# A single & or |, an identifier other than n, and anything else outside
# the grammar leave the expression untokenizable.
my $plural_tokenize__code_ref = sub {
    my $expression = shift;

    my @tokens;
    pos $expression = 0;
    TOKEN:
    while ( pos $expression < length $expression ) {
        $expression =~ m{ \G [ \t]+ }xmsgc
            and next TOKEN;
        $expression =~ m{
            \G (
                [0-9]+ | n \b
                | \|\| | && | == | != | <= | >=
                | [-+*/%<>?:!()]
            )
        }xmsgc
            or return;
        push @tokens, $1;
    }

    return \@tokens;
};

# Binary operators by C precedence, lowest binding first.  The
# conditional binds lower still and is right associative, so it is
# parsed separately.
my @plural_binary_operators = (
    [ q{||} ],
    [ q{&&} ],
    [ q{==}, q{!=} ],
    [ q{<}, q{>}, q{<=}, q{>=} ],
    [ q{+}, q{-} ],
    [ q{*}, q{/}, q{%} ],
);

my $plural_expression__code_ref;
my $plural_binary__code_ref;
my $plural_unary__code_ref;

# Each parser returns the Perl source for what it accepted, or nothing
# if the tokens are not that production.
$plural_expression__code_ref = sub {
    my ( $tokens, $index_ref ) = @_;

    my $condition = $plural_binary__code_ref->( $tokens, $index_ref, 0 );
    defined $condition
        or return;
    my $token = $tokens->[ ${$index_ref} ];
    defined $token && $token eq q{?}
        or return $condition;
    ${$index_ref}++;
    my $then = $plural_expression__code_ref->( $tokens, $index_ref );
    defined $then
        or return;
    $token = $tokens->[ ${$index_ref} ];
    defined $token && $token eq q{:}
        or return;
    ${$index_ref}++;
    my $else = $plural_expression__code_ref->( $tokens, $index_ref );
    defined $else
        or return;

    return "( $condition ? $then : $else )";
};

$plural_binary__code_ref = sub {
    my ( $tokens, $index_ref, $level ) = @_;

    $level <= $#plural_binary_operators
        or return $plural_unary__code_ref->( $tokens, $index_ref );
    my $left = $plural_binary__code_ref->( $tokens, $index_ref, $level + 1 );
    defined $left
        or return;
    OPERATOR:
    while ( defined( my $token = $tokens->[ ${$index_ref} ] ) ) {
        grep { $token eq $_ } @{ $plural_binary_operators[$level] }
            or last OPERATOR;
        ${$index_ref}++;
        my $right = $plural_binary__code_ref->( $tokens, $index_ref, $level + 1 );
        defined $right
            or return;
        $left = "( $left $token $right )";
    }

    return $left;
};

$plural_unary__code_ref = sub {
    my ( $tokens, $index_ref ) = @_;

    my $token = $tokens->[ ${$index_ref} ];
    defined $token
        or return;
    if ( $token eq q{!} ) {
        ${$index_ref}++;
        my $operand = $plural_unary__code_ref->( $tokens, $index_ref );
        defined $operand
            or return;
        return "( ! $operand )";
    }
    if ( $token eq q{n} ) {
        ${$index_ref}++;
        return q{$n};
    }
    if ( $token =~ m{ \A [0-9]+ \z }xms ) {
        ${$index_ref}++;
        return $token;
    }
    if ( $token eq q{(} ) {
        ${$index_ref}++;
        my $inner = $plural_expression__code_ref->( $tokens, $index_ref );
        defined $inner
            or return;
        $token = $tokens->[ ${$index_ref} ];
        defined $token && $token eq q{)}
            or return;
        ${$index_ref}++;
        return "( $inner )";
    }

    return;
};

# Returns the nplurals count, the plural expression as it stands in the
# header, and the Perl source generated from it, or nothing if the
# header is not a gettext plural header.
my $plural_forms_parse__code_ref = sub {
    my $plural_forms = shift;

    defined $plural_forms
        or return;
    my ( $nplurals, $plural ) = $plural_forms =~ m{
        \A
        nplurals [ ]* = [ ]* ( [0-9]+ ) [ ]* ;
        [ ]*
        plural   [ ]* = [ ]* ( [^;\n]+? ) [ ]* ;? [ ]*
        \z
    }xms
        or return;
    my $tokens = $plural_tokenize__code_ref->($plural)
        or return;
    my $index = 0;
    my $code = $plural_expression__code_ref->( $tokens, \$index );
    defined $code && $index == @{$tokens}
        or return;

    return ( 0 + $nplurals, $plural, $code );
};

my $plural_code__code_ref = sub {
    my $plural_expression = shift;

    my $code = <<"EOC";
        sub {
            my \$n = shift;

            return 0 + ( $plural_expression );
        }
EOC
    my $code_ref = eval $code;

    return $code_ref;
};

sub extract_header_msgstr {
    my ( $class, $header_msgstr ) = @_;

    defined $header_msgstr
        or die 'Header is not defined';
    ## no critic (ComplexRegexes)
    my ( $plural_forms ) = $header_msgstr =~ m{
        ^
        Plural-Forms:
        [ ]*
        (
            nplurals [ ]* [=] [ ]* \d+   [ ]* [;]
            [ ]*
            plural   [ ]* [=] [ ]* [^;\n]+ [ ]* [;]?
            [ ]*
        )
        $
    }xms
        or die 'Plural-Forms not found in header';
    ## use critic (ComplexRegexes)
    my ( $nplurals, $plural, $plural_expression )
        = $plural_forms_parse__code_ref->($plural_forms);
    defined $plural_expression
        or die 'Plural-Forms is not a gettext plural expression';
    my ( $charset ) = $header_msgstr =~ m{
        ^
        Content-Type:
        [^;]+ [;] [ ]*
        charset [ ]* = [ ]*
        ( [^ ]+ )
        [ ]*
        $
    }xms
        or die 'Content-Type with charset not found in header';
    my ( $multiplural_nplurals ) = $header_msgstr =~ m{
        ^ X-Multiplural-Nplurals: [ ]* ( \d+ ) [ ]* $
    }xms;

    return {(
        nplurals    => $nplurals,
        plural      => $plural,
        plural_code => $plural_code__code_ref->($plural_expression),
        charset     => $charset,
        (
            $multiplural_nplurals
            ? ( multiplural_nplurals => $multiplural_nplurals )
            : ()
        ),
    )};
}

sub module_path {
  (my $filename = __PACKAGE__ ) =~ s#::#/#g;
  $filename .= '.pm';
  my $path = $INC{$filename};
  return $path;
}


1;
