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

$r->get('/')->to(path => 'user', cmd => 'list')->name('user_defualt');

$r->get('/user/list')->to(path => 'user', cmd => 'list')->name('user__list');

$r->post('/user/add')->to(path => 'user', cmd => 'add')->name('user__add');

$r->any('/user/info')->name('user__info')->to('user#info');

$r->any([qw(POST PUT PATCH)] => '/user/edit')->name('user__edit')->to(path => 'user', cmd => 'edit');

$r->get('/user/standart/:name')->to(path => 'user', cmd => 'standart_name')->name('user__standart_name');

$r->get('/user/relaxed/#name')->to(path => 'user', cmd => 'relaxed_name')->name('user__relaxed_name');

$r->get('/user/wildcard/*name')->to(path => 'user', cmd => 'wildcard_name')->name('user__wildcard_name');

$r->post('/user/:action/:id')->name('user__action')->to(path => 'user', cmd => 'action');

$r->get('/user/:id')->name('user__profile')->to(path => 'user', cmd => 'profile')
  ->conditions(id => qr/\A[1-9][0-9]*\z/);

$r->get('/user/:id/settings')->name('user__settings')->to(path => 'user', cmd => 'settings')->conditions(
    id => sub {
        my ($web_interface, $params) = @_;

        return $params->{'id'} >= 1_000 && $params->{'id'} <= 1_500;
    }
);

$r->get('/user/scheme')->conditions(scheme => qr/https/)->to(path => 'user', cmd => 'scheme')->name('user__sheme');

$r->get('/user/mobile')->conditions(user_agent => qr/IEMobile/)->to(path => 'user', cmd => 'mobile')
  ->name('user__mobile');

cmp_deeply(
    $r->{'__ROUTES__'},
    {
        '/user/list' => {
            'params'     => [],
            'methods'    => 1,
            'route_path' => {
                'cmd'  => 'list',
                'path' => 'user'
            },
            'is_regexp' => 0,
            'pattern'   => '\A\/user\/list\/\z',
            'levels'    => 2,
            'name'      => 'user__list'
        },
        '/' => {
            'name'       => 'user_defualt',
            'levels'     => 0,
            'pattern'    => '\A\/\z',
            'is_regexp'  => 0,
            'route_path' => {
                'path' => 'user',
                'cmd'  => 'list'
            },
            'methods' => 1,
            'params'  => []
        },
        '/user/:id' => {
            'is_regexp'  => 1,
            'pattern'    => '\A\/user\/([^\/.]+)\/\z',
            'params'     => ['id'],
            'route_path' => {
                'cmd'  => 'profile',
                'path' => 'user'
            },
            'methods'    => 1,
            'conditions' => {'id' => qr/\A[1-9][0-9]*\z/},
            'name'       => 'user__profile',
            'levels'     => 2
        },
        '/user/info' => {
            'params'     => [],
            'route_path' => {
                'cmd'  => 'info',
                'path' => 'user'
            },
            'methods'   => 127,
            'is_regexp' => 0,
            'pattern'   => '\A\/user\/info\/\z',
            'levels'    => 2,
            'name'      => 'user__info'
        },
        '/user/mobile' => {
            'is_regexp'  => 0,
            'pattern'    => '\A\/user\/mobile\/\z',
            'route_path' => {
                'path' => 'user',
                'cmd'  => 'mobile'
            },
            'methods'    => 1,
            'params'     => [],
            'conditions' => {'user_agent' => qr/IEMobile/},
            'name'       => 'user__mobile',
            'levels'     => 2
        },
        '/user/:action/:id' => {
            'params'     => ['action', 'id'],
            'methods'    => 4,
            'route_path' => {
                'cmd'  => 'action',
                'path' => 'user'
            },
            'pattern'   => '\A\/user\/([^\/.]+)\/([^\/.]+)\/\z',
            'is_regexp' => 1,
            'levels'    => 3,
            'name'      => 'user__action'
        },
        '/user/standart/:name' => {
            'name'       => 'user__standart_name',
            'levels'     => 3,
            'is_regexp'  => 1,
            'pattern'    => '\A\/user\/standart\/([^\/.]+)\/\z',
            'params'     => ['name'],
            'methods'    => 1,
            'route_path' => {
                'cmd'  => 'standart_name',
                'path' => 'user'
            }
        },
        '/user/add' => {
            'is_regexp'  => 0,
            'pattern'    => '\A\/user\/add\/\z',
            'params'     => [],
            'route_path' => {
                'cmd'  => 'add',
                'path' => 'user'
            },
            'methods' => 4,
            'name'    => 'user__add',
            'levels'  => 2
        },
        '/user/scheme' => {
            'conditions' => {'scheme' => qr/https/},
            'levels'     => 2,
            'name'       => 'user__sheme',
            'methods'    => 1,
            'route_path' => {
                'path' => 'user',
                'cmd'  => 'scheme'
            },
            'params'    => [],
            'is_regexp' => 0,
            'pattern'   => '\A\/user\/scheme\/\z'
        },
        '/user/wildcard/*name' => {
            'methods'    => 1,
            'route_path' => {
                'cmd'  => 'wildcard_name',
                'path' => 'user'
            },
            'params'    => ['name'],
            'pattern'   => '\A\/user\/wildcard\/(.+)\/\z',
            'is_regexp' => 1,
            'levels'    => 3,
            'name'      => 'user__wildcard_name'
        },
        '/user/:id/settings' => {
            'name'       => 'user__settings',
            'levels'     => 3,
            'conditions' => {'id' => ignore(),},
            'is_regexp'  => 1,
            'pattern'    => '\A\/user\/([^\/.]+)\/settings\/\z',
            'params'     => ['id'],
            'route_path' => {
                'cmd'  => 'settings',
                'path' => 'user'
            },
            'methods' => 1
        },
        '/user/edit' => {
            'params'     => [],
            'methods'    => 28,
            'route_path' => {
                'path' => 'user',
                'cmd'  => 'edit'
            },
            'pattern'   => '\A\/user\/edit\/\z',
            'is_regexp' => 0,
            'levels'    => 2,
            'name'      => 'user__edit'
        },
        '/user/relaxed/#name' => {
            'is_regexp'  => 1,
            'pattern'    => '\A\/user\/relaxed\/([^\/]+)\/\z',
            'route_path' => {
                'path' => 'user',
                'cmd'  => 'relaxed_name'
            },
            'methods' => 1,
            'params'  => ['name'],
            'name'    => 'user__relaxed_name',
            'levels'  => 3
        },
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
        cmd    => 'list',
        params => {id => 1},
    )
);

cmp_deeply([$wi->get_cmd()], ['user', 'list'], 'GET "/user/list?id=1"');

$wi->request(
    get_request(
        path   => 'user',
        cmd    => 'list/',
        params => {id => 1},
    )
);

cmp_deeply([$wi->get_cmd()], ['user', 'list'], 'GET "/user/list/?id=1"');

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
        cmd    => 'info',
        method => 'HEAD',
    )
);

cmp_deeply([$wi->get_cmd()], ['user', 'info'], 'HEAD "/user/info"');

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

#
# conditions
#

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

done_testing;
