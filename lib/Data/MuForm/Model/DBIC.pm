package Data::MuForm::Model::DBIC;
# ABSTRACT: MuForm class with DBIC model already applied

use Moo;
extends 'Data::MuForm';
with 'Data::MuForm::Role::Model::DBIC';

1;
