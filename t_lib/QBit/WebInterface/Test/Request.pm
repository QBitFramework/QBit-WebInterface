package QBit::WebInterface::Test::Request;

use qbit;

use base qw(QBit::WebInterface::Request);

__PACKAGE__->mk_accessors(qw(r));

sub http_header {
    my ($self, $name) = @_;

    my $value = $self->{'headers'}{$name};

    return defined($value) ? $value : '';
}

sub method {shift->{'method'}}

sub uri {
    my ($self) = @_;

    my $result = "/$self->{'path'}";
    $result .= "/$self->{'cmd'}" if defined($self->{'cmd'});
    $result .= '?' . $self->{'query'} if defined($self->{'query'});
    
    return $result;
}

sub scheme {shift->{'scheme'}}

sub server_name {'Test'}

sub server_port {0}

sub remote_addr {'127.0.0.1'}

sub query_string {shift->{'query'}}

TRUE;
