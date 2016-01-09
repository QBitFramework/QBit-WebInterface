use FindBin qw($Bin);

use lib "$Bin/../lib";
use lib "$Bin/../t_lib";

use Test::More;
use Test::Deep;

use qbit;

use QBit::WebInterface::Routing;
use QBit::WebInterface::Test::Request;
use URI::Escape qw(uri_escape_utf8);

use TestWebInterface;

my $wi = new_ok('TestWebInterface');
$wi->pre_run();

sub get_request {
    my (%opts) = @_;

    return QBit::WebInterface::Test::Request->new(
        path  => $opts{'path'},
        cmd   => $opts{'cmd'},
        query => $opts{'params'}
        ? join('&',
            map {uri_escape_utf8($_) . '=' . uri_escape_utf8($opts{'params'}->{$_})} keys(%{$opts{'params'} || {}}))
        : undef,
        method  => $opts{'method'}  || 'GET',
        headers => $opts{'headers'} || {},
        scheme  => $opts{'scheme'}  || 'http'
    );
}

my $r = QBit::WebInterface::Routing->new();

my $error = FALSE;
try {
    $r->get('user');
}
catch {
    $error = TRUE;

    is(shift->message, gettext('Route must begin with "/"'), 'Corrected error');
}
finally {
    ok($error, 'throw exception');
};

$r->get('/')->to(path => 'user', cmd => 'list')->name('user_defualt');

$r->get('/user/without_last_slash')->to(path => 'user', cmd => 'without_last_slash')->name('user__without_last_slash');

$r->get('/user/with_last_slash/')->to(path => 'user', cmd => 'with_last_slash')->name('user__with_last_slash');

$r->post('/user/add')->to(path => 'user', cmd => 'add')->name('user__add');

$r->any('/user/info**')->name('user__info')->to('user#info');

$r->any([qw(POST PUT PATCH)] => '/user/edit')->name('user__edit')->to(path => 'user', cmd => 'edit');

$r->get('/user/standart/:name:')->to(path => 'user', cmd => 'standart_name')->name('user__standart_name');

$r->get('/user/relaxed/#name#')->to(path => 'user', cmd => 'relaxed_name')->name('user__relaxed_name');

$r->get('/user/wildcard/*name*')->to(path => 'user', cmd => 'wildcard_name')->name('user__wildcard_name');

$r->post('/user/:action:/:id:')->name('user__action')->to(path => 'user', cmd => 'action');

$r->get('/user/:name:-:surname:')->to(
    sub {
        my ($web_interface, $params) = @_;

        if ($params->{'name'} eq 'vasya') {
            return ('user', 'name_surname_vasya');
        } elsif ($params->{'name'} eq 'petya') {
            return ('user', 'name_surname_petya');
        } else {
            return ('', '');
        }
    }
)->name('user__name_surname');

$r->get('/user/:id:')->name('user__profile')->to(path => 'user', cmd => 'profile')
  ->conditions(id => qr/\A[1-9][0-9]*\z/);

$r->get('/user/:id:/settings')->name('user__settings')->to(path => 'user', cmd => 'settings')->conditions(
    id => sub {
        my ($web_interface, $chek_value, $params) = @_;

        return $chek_value >= 1_000 && $chek_value <= 1_500;
    }
);

$r->get('/user/scheme')->conditions(scheme => qr/https/)->to(path => 'user', cmd => 'scheme')->name('user__sheme');

$r->get('/user/mobile')->conditions(user_agent => qr/IEMobile/)->to(path => 'user', cmd => 'mobile')
  ->name('user__mobile');

$r->put('/user/:login:')->conditions(login => [qw(bender)])->to('user#bender');

cmp_deeply(
    $r->{'__ROUTES__'},
    {
        '/user/without_last_slash' => {
            'name'       => 'user__without_last_slash',
            'format'     => '/user/without_last_slash',
            'params'     => [],
            'route_path' => {
                'cmd'  => 'without_last_slash',
                'path' => 'user'
            },
            'methods' => 1,
            'pattern' => '\A\/user\/without_last_slash\z',
            'levels'  => 2
        },
        '/user/:action:/:id:' => {
            'format'     => '/user/%s/%s',
            'name'       => 'user__action',
            'route_path' => {
                'path' => 'user',
                'cmd'  => 'action'
            },
            'params'  => ['action', 'id'],
            'pattern' => '\A\/user\/([^\/.]+)\/([^\/.]+)\z',
            'methods' => 4,
            'levels'  => 3
        },
        '/user/scheme' => {
            'name'       => 'user__sheme',
            'format'     => '/user/scheme',
            'pattern'    => '\A\/user\/scheme\z',
            'methods'    => 1,
            'levels'     => 2,
            'conditions' => {'scheme' => qr/https/},
            'route_path' => {
                'path' => 'user',
                'cmd'  => 'scheme'
            },
            'params' => []
        },
        '/' => {
            'levels'     => 0,
            'format'     => '/',
            'name'       => 'user_defualt',
            'params'     => [],
            'route_path' => {
                'path' => 'user',
                'cmd'  => 'list'
            },
            'methods' => 1,
            'pattern' => '\A\/\z'
        },
        '/user/:id:/settings' => {
            'route_path' => {
                'cmd'  => 'settings',
                'path' => 'user'
            },
            'params'     => ['id'],
            'methods'    => 1,
            'pattern'    => '\A\/user\/([^\/.]+)\/settings\z',
            'format'     => '/user/%s/settings',
            'name'       => 'user__settings',
            'conditions' => {'id' => ignore()},
            'levels'     => 3
        },
        '/user/mobile' => {
            'conditions' => {'user_agent' => qr/IEMobile/},
            'levels'     => 2,
            'pattern'    => '\A\/user\/mobile\z',
            'methods'    => 1,
            'name'       => 'user__mobile',
            'format'     => '/user/mobile',
            'route_path' => {
                'cmd'  => 'mobile',
                'path' => 'user'
            },
            'params' => []
        },
        '/user/relaxed/#name#' => {
            'route_path' => {
                'path' => 'user',
                'cmd'  => 'relaxed_name'
            },
            'params'  => ['name'],
            'pattern' => '\A\/user\/relaxed\/([^\/]+)\z',
            'methods' => 1,
            'name'    => 'user__relaxed_name',
            'format'  => '/user/relaxed/%s',
            'levels'  => 3
        },
        '/user/add' => {
            'levels'     => 2,
            'format'     => '/user/add',
            'name'       => 'user__add',
            'route_path' => {
                'cmd'  => 'add',
                'path' => 'user'
            },
            'methods' => 4,
            'params'  => [],
            'pattern' => '\A\/user\/add\z'
        },
        '/user/info**' => {
            'levels'     => 2,
            'route_path' => {
                'cmd'  => 'info',
                'path' => 'user'
            },
            'methods' => 127,
            'params'  => [],
            'pattern' => '\A\/user\/info\*\z',
            'name'    => 'user__info',
            'format'  => '/user/info*'
        },
        '/user/:id:' => {
            'name'       => 'user__profile',
            'format'     => '/user/%s',
            'methods'    => 1,
            'pattern'    => '\A\/user\/([^\/.]+)\z',
            'levels'     => 2,
            'conditions' => {'id' => qr/\A[1-9][0-9]*\z/},
            'params'     => ['id'],
            'route_path' => {
                'path' => 'user',
                'cmd'  => 'profile'
            }
        },
        '/user/standart/:name:' => {
            'levels'     => 3,
            'name'       => 'user__standart_name',
            'format'     => '/user/standart/%s',
            'methods'    => 1,
            'route_path' => {
                'cmd'  => 'standart_name',
                'path' => 'user'
            },
            'pattern' => '\A\/user\/standart\/([^\/.]+)\z',
            'params'  => ['name']
        },
        '/user/wildcard/*name*' => {
            'format'     => '/user/wildcard/%s',
            'name'       => 'user__wildcard_name',
            'params'     => ['name'],
            'route_path' => {
                'path' => 'user',
                'cmd'  => 'wildcard_name'
            },
            'pattern' => '\A\/user\/wildcard\/(.+)\z',
            'methods' => 1,
            'levels'  => 3
        },
        '/user/with_last_slash/' => {
            'levels'     => 2,
            'route_path' => {
                'cmd'  => 'with_last_slash',
                'path' => 'user'
            },
            'methods' => 1,
            'params'  => [],
            'pattern' => '\A\/user\/with_last_slash\/\z',
            'format'  => '/user/with_last_slash/',
            'name'    => 'user__with_last_slash'
        },
        '/user/:login:' => {
            'conditions' => {'login' => ['bender']},
            'levels'     => 2,
            'route_path' => {
                'cmd'  => 'bender',
                'path' => 'user'
            },
            'pattern' => '\A\/user\/([^\/.]+)\z',
            'params'  => ['login'],
            'methods' => 8,
            'format'  => '/user/%s'
        },
        '/user/:name:-:surname:' => {
            'levels'     => 2,
            'name'       => 'user__name_surname',
            'format'     => '/user/%s-%s',
            'params'     => ['name', 'surname'],
            'route_path' => ignore(),
            'methods'    => 1,
            'pattern'    => '\A\/user\/([^\/.]+)\-([^\/.]+)\z'
        },
        '/user/edit' => {
            'levels'     => 2,
            'route_path' => {
                'path' => 'user',
                'cmd'  => 'edit'
            },
            'pattern' => '\A\/user\/edit\z',
            'methods' => 28,
            'params'  => [],
            'format'  => '/user/edit',
            'name'    => 'user__edit'
        }
    },
    'Routes'
);

$wi->routing($r);

$wi->request(get_request(path => '',));

cmp_deeply([$wi->get_cmd()], ['user', 'list'], 'GET "/"');

$wi->request(
    get_request(
        path   => '',
        method => 'POST',
    )
);

cmp_deeply([$wi->get_cmd()], ['', ''], 'POST "/" not found');

$wi->request(
    get_request(
        path   => 'user',
        cmd    => 'without_last_slash',
        params => {id => 1},
    )
);

cmp_deeply([$wi->get_cmd()], ['user', 'without_last_slash'], 'GET "/user/without_last_slash?id=1"');

$wi->request(
    get_request(
        path   => 'user',
        cmd    => 'without_last_slash/',
        params => {id => 1},
    )
);

cmp_deeply([$wi->get_cmd()], ['', ''], 'GET "/user/without_last_slash/?id=1"');

$wi->request(
    get_request(
        path   => 'user',
        cmd    => 'with_last_slash',
        params => {id => 1},
    )
);

cmp_deeply([$wi->get_cmd()], ['', ''], 'GET "/user/with_last_slash?id=1"');

$wi->request(
    get_request(
        path   => 'user',
        cmd    => 'with_last_slash/',
        params => {id => 1},
    )
);

cmp_deeply([$wi->get_cmd()], ['user', 'with_last_slash'], 'GET "/user/with_last_slash/?id=1"');

$wi->request(
    get_request(
        path   => 'user',
        cmd    => 'add',
        method => 'POST',
    )
);

cmp_deeply([$wi->get_cmd()], ['user', 'add'], 'POST "/user/add"');

$wi->request(
    get_request(
        path   => 'user',
        cmd    => 'info*',
        method => 'HEAD',
    )
);

cmp_deeply([$wi->get_cmd()], ['user', 'info'], 'HEAD "/user/info*"');

$wi->request(
    get_request(
        path   => 'user',
        cmd    => 'edit',
        method => 'POST',
        params => {id => 1},
    )
);

cmp_deeply([$wi->get_cmd()], ['user', 'edit'], 'POST "/user/edit?id=1"');

#
# standart placeholders
#

$wi->request(
    get_request(
        path => 'user',
        cmd  => 'standart/vasya',
    )
);

cmp_deeply([$wi->get_cmd()], ['user', 'standart_name'], 'GET "/user/standart/vasya"');

cmp_deeply($wi->get_option('url_params'), {name => 'vasya'}, 'Check url params');

$wi->request(
    get_request(
        path => 'user',
        cmd  => 'standart/vasya pupkin',
    )
);

cmp_deeply([$wi->get_cmd()], ['user', 'standart_name'], 'GET "/user/standart/vasya pupkin"');

cmp_deeply($wi->get_option('url_params'), {name => 'vasya pupkin'}, 'Check url params');

$wi->request(
    get_request(
        path => 'user',
        cmd  => 'standart/vasya.pupkin',
    )
);

cmp_deeply([$wi->get_cmd()], ['', ''], 'GET "/user/standart/vasya.pupkin" not found');

cmp_deeply($wi->get_option('url_params'), undef, 'Check url params');

$wi->request(
    get_request(
        path => 'user',
        cmd  => 'standart/vasya/pupkin',
    )
);

cmp_deeply([$wi->get_cmd()], ['', ''], 'GET "/user/standart/vasya/pupkin" not found');

cmp_deeply($wi->get_option('url_params'), undef, 'Check url params');

#
# relaxed placeholders
#

$wi->request(
    get_request(
        path => 'user',
        cmd  => 'relaxed/vasya',
    )
);

cmp_deeply([$wi->get_cmd()], ['user', 'relaxed_name'], 'GET "/user/relaxed/vasya"');

cmp_deeply($wi->get_option('url_params'), {name => 'vasya'}, 'Check url params');

$wi->request(
    get_request(
        path => 'user',
        cmd  => 'relaxed/vasya pupkin',
    )
);

cmp_deeply([$wi->get_cmd()], ['user', 'relaxed_name'], 'GET "/user/relaxed/vasya pupkin"');

cmp_deeply($wi->get_option('url_params'), {name => 'vasya pupkin'}, 'Check url params');

$wi->request(
    get_request(
        path => 'user',
        cmd  => 'relaxed/vasya.pupkin',
    )
);

cmp_deeply([$wi->get_cmd()], ['user', 'relaxed_name'], 'GET "/user/relaxed/vasya.pupkin"');

cmp_deeply($wi->get_option('url_params'), {name => 'vasya.pupkin'}, 'Check url params');

$wi->request(
    get_request(
        path => 'user',
        cmd  => 'relaxed/vasya/pupkin',
    )
);

cmp_deeply([$wi->get_cmd()], ['', ''], 'GET "/user/relaxed/vasya/pupkin" not found');

cmp_deeply($wi->get_option('url_params'), undef, 'Check url params');

#
# wildcard placeholders
#

$wi->request(
    get_request(
        path => 'user',
        cmd  => 'wildcard/vasya',
    )
);

cmp_deeply([$wi->get_cmd()], ['user', 'wildcard_name'], 'GET "/user/wildcard/vasya"');

cmp_deeply($wi->get_option('url_params'), {name => 'vasya'}, 'Check url params');

$wi->request(
    get_request(
        path => 'user',
        cmd  => 'wildcard/vasya pupkin',
    )
);

cmp_deeply([$wi->get_cmd()], ['user', 'wildcard_name'], 'GET "/user/wildcard/vasya pupkin"');

cmp_deeply($wi->get_option('url_params'), {name => 'vasya pupkin'}, 'Check url params');

$wi->request(
    get_request(
        path => 'user',
        cmd  => 'wildcard/vasya.pupkin',
    )
);

cmp_deeply([$wi->get_cmd()], ['user', 'wildcard_name'], 'GET "/user/wildcard/vasya.pupkin"');

cmp_deeply($wi->get_option('url_params'), {name => 'vasya.pupkin'}, 'Check url params');

$wi->request(
    get_request(
        path => 'user',
        cmd  => 'wildcard/vasya/pupkin',
    )
);

cmp_deeply([$wi->get_cmd()], ['user', 'wildcard_name'], 'GET "/user/wildcard/vasya/pupkin"');

cmp_deeply($wi->get_option('url_params'), {name => 'vasya/pupkin'}, 'Check url params');

#
# More placeholders
#

$wi->request(
    get_request(
        path   => 'user',
        cmd    => 'delete/2',
        method => 'POST',
    )
);

cmp_deeply([$wi->get_cmd()], ['user', 'action'], 'POST "/user/delete/2"');

cmp_deeply($wi->get_option('url_params'), {action => 'delete', id => 2}, 'Check url params');

$wi->request(
    get_request(
        path => 'user',
        cmd  => 'vasya-pupkin',
    )
);

cmp_deeply([$wi->get_cmd()], ['user', 'name_surname_vasya'], 'GET "/user/vasya-pupkin"');

cmp_deeply($wi->get_option('url_params'), {name => 'vasya', surname => 'pupkin'}, 'Check url params');

$wi->request(
    get_request(
        path => 'user',
        cmd  => 'petya-pupkin',
    )
);

cmp_deeply([$wi->get_cmd()], ['user', 'name_surname_petya'], 'GET "/user/petya-pupkin"');

cmp_deeply($wi->get_option('url_params'), {name => 'petya', surname => 'pupkin'}, 'Check url params');

#
# conditions
#

# array

$wi->request(
    get_request(
        path   => 'user',
        cmd    => 'fry',
        method => 'PUT',
        params => {name => 'vasya'},
    )
);

cmp_deeply([$wi->get_cmd()], ['', ''], 'PUT "/user/fry" not found');

$wi->request(
    get_request(
        path   => 'user',
        cmd    => 'bender',
        method => 'PUT',
        params => {name => 'vasya'},
    )
);

cmp_deeply([$wi->get_cmd()], ['user', 'bender'], 'PUT "/user/bender"');

cmp_deeply($wi->get_option('url_params'), {login => 'bender'}, 'Check url params');

# regexp
$wi->request(
    get_request(
        path => 'user',
        cmd  => 'vasya',
    )
);

cmp_deeply([$wi->get_cmd()], ['', ''], 'GET "/user/vasya" not found');

$wi->request(
    get_request(
        path => 'user',
        cmd  => '1',
    )
);

cmp_deeply([$wi->get_cmd()], ['user', 'profile'], 'GET "/user/1"');

cmp_deeply($wi->get_option('url_params'), {id => 1}, 'Check url params');

# sub

$wi->request(
    get_request(
        path => 'user',
        cmd  => '1/settings',
    )
);

cmp_deeply([$wi->get_cmd()], ['', ''], 'GET "/user/1/settings" not found');

$wi->request(
    get_request(
        path => 'user',
        cmd  => '1111/settings',
    )
);

cmp_deeply([$wi->get_cmd()], ['user', 'settings'], 'GET "/user/1111/settings"');

cmp_deeply($wi->get_option('url_params'), {id => 1111}, 'Check url params');

# check data from methods Request

$wi->request(
    get_request(
        path   => 'user',
        cmd    => 'scheme',
        scheme => 'http',
    )
);

cmp_deeply([$wi->get_cmd()], ['', ''], 'GET "/user/scheme" not found');

$wi->request(
    get_request(
        path   => 'user',
        cmd    => 'scheme',
        scheme => 'https',
    )
);

cmp_deeply([$wi->get_cmd()], ['user', 'scheme'], 'GET "/user/scheme"');

# check data from method "http_header" Request

$wi->request(
    get_request(
        path    => 'user',
        cmd     => 'mobile',
        headers => {user_agent => 'Mozilla/5.0 (X11; Linux i586; rv:31.0) Gecko/20100101 Firefox/31.0',}
    )
);

cmp_deeply([$wi->get_cmd()], ['', ''], 'GET "/user/mobile" not found');

$wi->request(
    get_request(
        path    => 'user',
        cmd     => 'mobile',
        headers => {user_agent => 'HTC_Touch_3G Mozilla/4.0 (compatible; MSIE 6.0; Windows CE; IEMobile 7.11)',}
    )
);

cmp_deeply([$wi->get_cmd()], ['user', 'mobile'], 'GET "/user/mobile"');

#
# url_for
#

is($r->url_for('user__edit'), '/user/edit', 'url_for "user__edit"');

is(
    $r->url_for('user__edit', {}, id => 1, fio => 'vasya pupkin'),
    '/user/edit?fio=vasya%20pupkin&id=1',
    'url_for "user__edit" with params'
  );

is($r->url_for('user__info'), '/user/info*', 'url_for "user__info"');

is($r->url_for('user__name_surname', {name => 'vasya', surname => 'pupkin'},),
    '/user/vasya-pupkin', 'url_for "user__name_surname"');

#
# strictly
#

my $r2 = QBit::WebInterface::Routing->new(strictly => FALSE);

$r2->get('/user/without_last_slash')->to(path => 'user', cmd => 'without_last_slash')->name('user__without_last_slash');

$r2->get('/user/with_last_slash/')->to(path => 'user', cmd => 'with_last_slash')->name('user__with_last_slash');

cmp_deeply(
    $r2->{'__ROUTES__'},
    {
        '/user/with_last_slash/' => {
            'levels'     => 2,
            'name'       => 'user__with_last_slash',
            'format'     => '/user/with_last_slash/',
            'route_path' => {
                'cmd'  => 'with_last_slash',
                'path' => 'user'
            },
            'methods' => 1,
            'params'  => [],
            'pattern' => '\A\/user\/with_last_slash\/\z'
        },
        '/user/without_last_slash' => {
            'route_path' => {
                'cmd'  => 'without_last_slash',
                'path' => 'user'
            },
            'params'  => [],
            'pattern' => '\A\/user\/without_last_slash\/\z',
            'methods' => 1,
            'format'  => '/user/without_last_slash/',
            'name'    => 'user__without_last_slash',
            'levels'  => 2
        }
    },
    'Routes strictly => FALSE'
);

$wi->routing($r2);

$wi->request(
    get_request(
        path   => 'user',
        cmd    => 'without_last_slash',
        params => {id => 1},
    )
);

cmp_deeply([$wi->get_cmd()], ['user', 'without_last_slash'], 'GET "/user/without_last_slash?id=1"');

$wi->request(
    get_request(
        path   => 'user',
        cmd    => 'without_last_slash/',
        params => {id => 1},
    )
);

cmp_deeply([$wi->get_cmd()], ['user', 'without_last_slash'], 'GET "/user/without_last_slash/?id=1"');

$wi->request(
    get_request(
        path   => 'user',
        cmd    => 'with_last_slash',
        params => {id => 1},
    )
);

cmp_deeply([$wi->get_cmd()], ['user', 'with_last_slash'], 'GET "/user/with_last_slash?id=1"');

$wi->request(
    get_request(
        path   => 'user',
        cmd    => 'with_last_slash/',
        params => {id => 1},
    )
);

cmp_deeply([$wi->get_cmd()], ['user', 'with_last_slash'], 'GET "/user/with_last_slash/?id=1"');

is($r2->url_for('user__without_last_slash'), '/user/without_last_slash/', 'url_for "user__without_last_slash"');

is($r2->url_for('user__with_last_slash'), '/user/with_last_slash/', 'url_for "user__with_last_slash"');

#
# under
#

my $player = $r2->under('/player')->to('player#game')->conditions(server_name => sub {$_[1] eq 'Test'});

$player->get('/settings')->to('#settings')->conditions(remote_addr => sub {$_[1] eq '127.0.0.1'});

cmp_deeply(
    $player->{'__ROUTES__'},
    {
        '/player/settings' => {
            'methods'    => 1,
            'params'     => [],
            'conditions' => {
                'remote_addr' => ignore(),
                'server_name' => ignore(),
            },
            'pattern'    => '\A\/player\/settings\/\z',
            'format'     => '/player/settings/',
            'route_path' => ignore(),
            'levels'     => 2
        },
        '/user/without_last_slash' => {
            'params'     => [],
            'name'       => 'user__without_last_slash',
            'methods'    => 1,
            'pattern'    => '\A\/user\/without_last_slash\/\z',
            'route_path' => {
                'cmd'  => 'without_last_slash',
                'path' => 'user'
            },
            'format' => '/user/without_last_slash/',
            'levels' => 2
        },
        '/user/with_last_slash/' => {
            'name'       => 'user__with_last_slash',
            'params'     => [],
            'methods'    => 1,
            'levels'     => 2,
            'route_path' => {
                'path' => 'user',
                'cmd'  => 'with_last_slash'
            },
            'format'  => '/user/with_last_slash/',
            'pattern' => '\A\/user\/with_last_slash\/\z'
        }
    },
    'Routes player'
);

$wi->routing($r2);

$wi->request(
    get_request(
        path => 'player',
        cmd  => 'settings',
    )
);

cmp_deeply([$wi->get_cmd()], ['player', 'settings'], 'GET "/player/settings"');

done_testing;
