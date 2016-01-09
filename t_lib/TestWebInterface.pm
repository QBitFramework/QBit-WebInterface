package TestWebInterface;

use qbit;

use base qw(QBit::WebInterface::Test QBit::Application);

use TestWebInterface::Controller::Test path => 'test';

__PACKAGE__->config_opts(
    TemplateIncludePaths => ['${ApplicationPath}lib/../lib/QBit/templates', '${ApplicationPath}lib/templates']
    ,    # Use framework templates
    MinimizeTemplate => TRUE,
);

sub get_cmd {
    my ($self) = @_;

    return defined($self->routing()) ? $self->routing->get_cmd($self) : $self->SUPER::get_cmd();
}

TRUE;
