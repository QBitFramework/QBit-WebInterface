package Exception::Request;
use base qw(Exception);

package Exception::Request::UnknownMethod;
use base qw(Exception::Request);

package QBit::WebInterface::Request;

use qbit;

use base qw(QBit::Class);

__PACKAGE__->abstract_methods(
    qw(
      http_header
      method
      _uri
      scheme
      server_name
      server_port
      remote_addr
      query_string
      _read_from_stdin
      )
);

our $MAX_POST_REQEST_SIZE = 15 * 1024 * 1024;

sub param_names {
    my ($self) = @_;

    $self->_parse_params() unless exists($self->{'__PARAMS__'});

    return keys(%{$self->{'__PARAMS__'}});
}

sub param_array {
    my ($self, $name) = @_;

    $self->_parse_params() unless exists($self->{'__PARAMS__'});

    return $self->{'__PARAMS__'}{$name || ''} || [];
}

sub param {
    my ($self, $name, $default) = @_;

    my $res = $self->param_array($name)->[0];
    return defined($res) ? $res : $default;
}

sub cookie {
    my ($self, $name, $struc_type) = @_;

    $self->_parse_cookies() unless exists($self->{'__COOKIES__'});

    return undef unless $self->{'__COOKIES__'}{$name};
    my $cookie = [@{$self->{'__COOKIES__'}{$name}}];

    if (ref($struc_type) eq 'ARRAY') {
        return $cookie;
    } elsif (ref($struc_type) eq 'HASH') {
        push(@$cookie, undef) if @$cookie % 2;
        return {@$cookie};
    } else {
        return $cookie->[0];
    }
}

sub url {
    my ($self, %opts) = @_;

    my $url = $self->scheme() . '://';
    $url .= $self->server_name();
    $url .= ':' . $self->server_port() if !in_array($self->server_port(), [80, 443]);
    $url .= $self->uri() unless $opts{'no_uri'};

    return $url;
}

sub uri {
    my ($self) = @_;

    $self->{__URI__} ||= $self->_uri();

    return $self->{__URI__};
}

sub store_data {
    my ($self) = @_;

    $self->_parse_params() unless exists($self->{'__PARAMS__'});

    return {
        uri    => $self->uri,
        params => $self->{'__PARAMS__'},
    };
}

sub retrive_data {
    my ($self, $data) = @_;

    throw gettext('Invalid data to retrive request')
      unless ref($data) eq 'HASH' && defined($data->{'params'}) && defined($data->{'uri'});

    $self->{'__PARAMS__'} = $data->{'params'};
    $self->{'__URI__'}    = $data->{'uri'};

    return FALSE;
}

sub parse_query_string {
    my ($self, $query_string) = @_;

    return $self->_parse_pairs([$self->_parse_query_string($query_string)]);
}

sub _parse_params {
    my ($self) = @_;

    $self->{'__PARAMS__'} = {};

    my @pairs;

    if ($self->method eq 'GET' || $self->method eq 'HEAD') {
        push(@pairs, $self->_parse_query_string($self->query_string));
    } elsif ($self->method eq 'POST') {
        my ($buffer, $tmp, $size) = ('', '', 0);
        while (my $cnt = $self->_read_from_stdin(\$tmp, 1024 * 1024)) {
            $size += $cnt;
            throw gettext('Too big request') if $size > $MAX_POST_REQEST_SIZE;
            $buffer .= $tmp;
        }

        if ($self->http_header('content-type') =~ /^multipart\/form\-data/) {
            my ($spliter, $end, $data) = $buffer =~ m/^([^ \r\n]+)([\r\n]{1,2})(.*?)\2\1--.?.?$/s;

            foreach my $block (split(/$end\Q$spliter\E$end/, $data)) {
                my ($header, $content) = split($end . $end, $block, 2);

                my %header;

                foreach my $line (split(/(?:$end)|(?:\s*;\s*)/, $header)) {
                    my ($name, $value) = split(/=|:\s*/, $line, 2);
                    $value =~ s/^"?(.*?)"?$/$1/;
                    $header{$name} = $value;
                }

                if ($header{'filename'}) {
                    $self->_unescape(\$header{'filename'});
                    for ($header{'filename'}) {
                        s/^"([^"]+)"$/$1/;
                        s/[\\\/]([^\\\/]+)$/$1/;
                    }
                    push(@pairs, [$header{'name'}, {filename => $header{'filename'}, content => $content}]);
                } elsif ($header{name}) {
                    push(@pairs, [$header{'name'}, $content]);
                }
            }
        } else {
            push(@pairs, $self->_parse_query_string($buffer));
        }
    } else {
        throw Exception::Request::UnknownMethod gettext('Unknown method %s', $self->method);
    }

    $self->{'__PARAMS__'} = $self->_parse_pairs(\@pairs);
}

sub _parse_query_string {
    my ($self, $query_string) = @_;

    return map {[split('=', $_, 2)]} split('&', $query_string);
}

sub _parse_pairs {
    my ($self, $pairs) = @_;

    my %params;
    foreach (@$pairs) {
        my ($pname, $pvalue) = @$_;

        next unless defined($pname);

        $self->_unescape(\$pname);
        $self->_unescape(\$pvalue) if defined($pvalue) && !ref($pvalue);

        $params{$pname} = []
          unless exists($params{$pname});
        push(@{$params{$pname}}, $pvalue);
    }

    return \%params;
}

sub _parse_cookies {
    my ($self) = @_;

    $self->{'__COOKIES__'} = {};

    my $cookie_str = $self->http_header('Cookie');

    foreach (split('[;,] ?', $cookie_str)) {
        s/\s*(.*?)\s*/$1/;
        my ($key, $value) = split('=', $_, 2);
        next unless defined($key);

        my @values = defined($value) ? split(/[&;]/, $value) : ();
        $self->_unescape(\$_) foreach @values;

        $self->{'__COOKIES__'}{$key} ||= [];
        push(@{$self->{'__COOKIES__'}{$key}}, @values);
    }
}

sub _unescape {
    my ($self, $str_ptr) = @_;

    $$str_ptr =~ tr/+/ /;
    $$str_ptr =~ s/%([a-fA-F0-9][a-fA-F0-9])/pack("C", hex($1))/eg;
    utf8::decode($$str_ptr);
}

TRUE;
