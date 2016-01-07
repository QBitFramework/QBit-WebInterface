package Exception::Routing;

use base qw(Exception);

package QBit::WebInterface::Routing;

use qbit;

use base qw(QBit::Class);

my %METHODS = (
    GET     => 1,
    HEAD    => 2,
    POST    => 4,
    PUT     => 8,
    PATCH   => 16,
    DELETE  => 32,
    OPTIONS => 64,
);

sub get {shift->_generate_route(GET => @_)}

sub head {shift->_generate_route(HEAD => @_)}

sub post {shift->_generate_route(POST => @_)}

sub put {shift->_generate_route(PUT => @_)}

sub delete {shift->_generate_route(DELETE => @_)}

sub options {shift->_generate_route(OPTIONS => @_)}

sub any {
    my ($self, @args) = @_;

    if (@args == 1) {
        shift->_generate_route([keys(%METHODS)] => @args);
    } elsif (@args == 2) {
        shift->_generate_route(@args);
    } else {
        throw Exception::Routing gettext('Expected one or two arguments');
    }
}

sub _generate_route {
    my ($self, $methods, @args) = @_;

    while (my $arg = shift(@args)) {
        $self->{'__ROUTES__'}{$arg} = {
            methods => $self->_get_methods_bit($methods),
            %{$self->_get_settings($arg)}
        };

        $self->{'__LAST__'} = \$self->{'__ROUTES__'}{$arg};
    }

    return $self;
}

sub _get_settings {
    my ($self, $route_name) = @_;

    my @route_levels = split('/', $route_name);

    my $is_regexp = 0;
    my @params    = ();
    foreach my $route_level (@route_levels) {
        if ($route_level =~ /\A([\:#\*])([^?\/#]+)/) {
            if ($1 eq ':') {
                # /user/:id
                $route_level = '([^\/.]+)';
            } elsif ($1 eq '#') {
                # /user/#name
                $route_level = '([^\/]+)';
            } elsif ($1 eq '*') {
                # /user/*name
                $route_level = '(.+)';
            }

            push(@params, $2);

            $is_regexp = 1;
        } else {
            $route_level = quotemeta($route_level);
        }
    }

    my $pattern = @route_levels ? join('\/', @route_levels) : '\/';
    $pattern .= '\/' unless $pattern =~ m/\/\z/;

    return {
        pattern   => '\A' . $pattern . '\z',
        params    => \@params,
        levels    => scalar(grep {length($_)} @route_levels),
        is_regexp => $is_regexp,
    };
}

sub _get_methods_bit {
    my ($self, $methods) = @_;

    $methods = [$methods] unless ref($methods) eq 'ARRAY';

    my $methods_bit = $METHODS{shift(@$methods)};
    foreach my $method (@$methods) {
        $methods_bit |= $METHODS{$method};
    }

    return $methods_bit;
}

sub to {
    my ($self, @args) = @_;

    if (@args % 2 == 0) {
        ${$self->{'__LAST__'}}->{'route_path'} = {@args};
    } elsif (@args == 1) {
        my ($path, $cmd) = ($args[0] =~ m/\A([a-zA-Z_]+)#([a-zA-Z_]+)\z/);

        ${$self->{'__LAST__'}}->{'route_path'} = {path => $path, cmd => $cmd};
    }

    return $self;
}

sub name {
    my ($self, $name) = @_;

    my @routes_with_this_name =
      grep {$name eq ($self->{'__ROUTES__'}{$_}{'name'} // '')} keys(%{$self->{'__ROUTES__'}});
    throw Exception::Routing gettext('Name "%s" for route already exists', $name) if @routes_with_this_name;

    ${$self->{'__LAST__'}}->{'name'} = $name;

    return $self;
}

sub get_cmd {
    my ($self, $wi) = @_;

    $wi->set_option('url_params' => undef);

    my $method = $wi->request->method;
    my $uri    = $wi->request->uri;

    $uri =~ s/[?#].*\z//;
    $uri .= '/' unless $uri =~ m/\/\z/;

    my @routes = $self->_get_routes_by_methods($method);

    @routes = sort {$self->_sort_routes($a, $b)} @routes;

    foreach my $route (@routes) {
        my $pattern = $self->get_route($route)->{'pattern'};

        if (my @values = ($uri =~ m/$pattern/i)) {
            my %url_params = ();

            if (@{$self->get_route($route)->{'params'}}) {
                throw Exception::Routing gettext('Different number of parameters')
                  unless @{$self->get_route($route)->{'params'}} == @values;

                @url_params{@{$self->get_route($route)->{'params'}}} = @values;
            }

            if (exists($self->get_route($route)->{'conditions'})) {
                my $ok = TRUE;

                foreach my $condition_name (keys(%{$self->get_route($route)->{'conditions'}})) {
                    my $check_value;
                    if (exists($url_params{$condition_name})) {
                        $check_value = $url_params{$condition_name};
                    } elsif ($wi->request->can($condition_name)) {
                        $check_value = $wi->request->$condition_name();
                    } else {
                        $check_value = $wi->request->http_header($condition_name);
                    }

                    my $condition = $self->get_route($route)->{'conditions'}{$condition_name};

                    if (ref($condition) eq 'Regexp') {
                        $ok = $check_value =~ $condition;
                    } elsif (ref($condition) eq 'CODE') {
                        $ok = $condition->($wi, \%url_params);
                    } else {
                        throw Exception::Routing gettext('Unknown condition type "%s"', ref($condition));
                    }

                    last unless $ok;
                }

                next unless $ok;
            }

            $wi->set_option('url_params' => \%url_params) if %url_params;

            my $route_path = $self->get_route($route)->{'route_path'};

            throw Exception::Routing gettext('You did not specify the path of the route "%s"', $route)
              unless defined($route_path);

            return ($route_path->{'path'}, $route_path->{'cmd'});
        }
    }

    return ('', '');
}

sub _get_routes_by_methods {
    my ($self, $method) = @_;

    my @routes = ();

    foreach my $route (keys(%{$self->{'__ROUTES__'}})) {
        push(@routes, $route) if $METHODS{$method} & $self->{'__ROUTES__'}{$route}{'methods'};
    }

    return @routes;
}

sub _sort_routes {
    my ($self, $f, $s) = @_;

    my $result = $self->get_route($s)->{'levels'} <=> $self->get_route($f)->{'levels'};

    if ($result == 0) {
        if ($self->get_route($f)->{'is_regexp'} && !$self->get_route($s)->{'is_regexp'}) {
            $result = 1;
        } elsif (!$self->get_route($f)->{'is_regexp'} && $self->get_route($s)->{'is_regexp'}) {
            $result = -1;
        }
    }

    if ($result == 0) {
        if (exists($self->get_route($f)->{'conditions'}) && !exists($self->get_route($s)->{'conditions'})) {
            $result = -1;
        } elsif (!exists($self->get_route($f)->{'conditions'}) && exists($self->get_route($s)->{'conditions'})) {
            $result = 1;
        }
    }

    return $result;
}

sub get_route {
    my ($self, $route) = @_;

    return $self->{'__ROUTES__'}{$route} // {};
}

sub conditions {
    my ($self, %conditions) = @_;

    ${$self->{'__LAST__'}}->{'conditions'} = \%conditions;

    return $self;
}

TRUE;
