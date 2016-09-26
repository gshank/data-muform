package Data::MuForm::Localizer;
use Moo;

use Types::Standard -types;

=head1 NAME

Data::MuForm

=head1 DESCRIPTION

Moo conversion of HTML::FormHandler.

=cut

# create lexicon
has 'lexicon_search_dirs' => ( is => 'rw', isa => ArrayRef, lazy => 1, builder => 'build_lexicon_search_dirs' );
sub build_lexicon_search_dirs {
    my $self = shift;
    my $filename = __FILE__;
   $filename =~ s/Localizer.pm//;
   return  ["$filename/LocaleData"]
}
has 'lexicon_ref' => ( is => 'rw', builder => 'build_lexicon_ref' );
sub build_lexicon_ref {
  my $self = shift;
  require Locale::TextDomain::OO::Lexicon::File::PO;
  my $lexicon_ref = Locale::TextDomain::OO::Lexicon::File::PO->new->lexicon_ref({
      search_dirs => $self->lexicon_search_dirs,
      decode      => 1,
      data        => [ '*::' => '*/messages.po', ],
  });
  return $lexicon_ref;
}
has 'language' => ( is => 'rw', builder => 'build_language' );
sub build_language { 'en' }
has 'loc' => ( is => 'rw', lazy => 1, builder => 'build_loc' );
sub build_loc {
    my $self = shift;
    require Locale::TextDomain::OO;
    my $td = Locale::TextDomain::OO->new(
        language => $self->language,
        plugins  => [ 'Expand::Gettext' ],
    );
    return $td;
}

1;
