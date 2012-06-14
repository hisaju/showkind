package ShowKind;
use Dancer ':syntax';
use Dancer::Plugin::Database;
use Dancer::Plugin::Facebook;
use DateTime;
use Data::Dumper;
use Dancer::Plugin::ValidateTiny;
use Data::Page;
use HTML::TagCloud;

our $VERSION = '0.1';

before sub {
    if ( not request->path =~/^\/$/
     and not request->path =~/^\/login/
     and not request->path =~/^\/postback/
        and not session('fb_user') )
    {
    redirect uri_for('/');
    }
};

get '/' => sub {
    my $fb_user = session('fb_user');
    unless ($fb_user) {
        return template 'index.tt';
    }
    if (session('first')) {
        session('first', undef);
        return redirect uri_for('/choose/1');
    }

    template 'top';
};

get '/login' => sub {
    redirect fb->authorize->extend_permissions(qw/email publish_stream friends_relationships/)->uri_as_string;
};

get '/logout' => sub {
    session 'fb_user', undef;
    redirect uri_for('/');
};

get '/postback' => sub {
    my $code = params->{'code'};
    fb->request_access_token($code);
    my $user = fb->fetch('me');
    my $small = fb->picture($user->{id})->get_small->uri_as_string;
    my $large = fb->picture($user->{id})->get_large->uri_as_string;

    my $db_user = database->quick_select('users', {fb_user_id => $user->{'id'}});

    if ($db_user) {
        database->quick_update('users', {id => $db_user->{id}}, {
            fb_access_token => fb->access_token,
            small_picture => $small,
            large_picture => $large,
            name => $user->{name}
        });
    }
    else {
        my $dt = DateTime->now( time_zone => 'Asia/Tokyo' );
        database->quick_insert('users', {
            fb_user_id => $user->{id},
            name => $user->{name},
            small_picture => $small,
            large_picture => $large,
            fb_access_token => fb->access_token,
            created_at => $dt->strftime('%Y-%m-%d %H:%M:%S'),
        });
        $db_user = database->quick_select('users', {fb_user_id => $user->{'id'}});
        session 'first', '1';
    }
    session 'fb_user', $db_user;
    redirect uri_for('/');
};

get '/choose/:page' => sub {

    my $fb_user = session 'fb_user';
    fb->access_token($fb_user->{fb_access_token});

    my $fql=<<EOF;
SELECT uid, name, pic_small  FROM user WHERE uid IN (SELECT uid2 FROM friend WHERE uid1 = me())  and relationship_status != 'Engaged' and relationship_status != 'Married'
EOF
    my $list = fb->fql($fql)->{data};

    my $page = param('page');
    $page = 1 unless $page;

    my $pager = Data::Page->new(scalar @$list, 50, $page);
    my @newlist = $pager->splice($list);

    template 'choose', {list => \@newlist, pager => $pager};
};

get '/recommend/:id' => sub {

    my $fb_user = session 'fb_user';
    fb->access_token($fb_user->{fb_access_token});

    my $id = param('id');
    my $target = fb->query->find($id)->select_fields(qw(id name gender picture))->request->as_hashref;

    my %result = (target => $target);
    if (my $error = session('error')) {
        $result{error} = $error;
        session 'error', undef;
    }
    template 'recommend', \%result;
};

post '/register' => sub {

    my $fb_user = session 'fb_user';
    fb->access_token($fb_user->{fb_access_token});

    # validation
    my $params = params;
    my $data = validator($params, 'validate_recommend.pl');
    unless ($data->{valid}) {
        session 'error', $data->{result};
        return redirect uri_for('/recommend/' . param('fb_user_id'));
    }

    my $user = session('fb_user');
    my $dt = DateTime->now( time_zone => 'Asia/Tokyo' );
    my $target = fb->query->find(param('fb_user_id'))->select_fields(qw(id name gender))->request->as_hashref;

    my $recommend_user = database->quick_select('recommend_users', {fb_user_id => $target->{'id'}});
    unless ($recommend_user) {
        my $small = fb->picture($target->{id})->get_small->uri_as_string;
        my $large = fb->picture($target->{id})->get_large->uri_as_string;
        database->quick_insert('recommend_users', {
            fb_user_id => $target->{id},
            name => $target->{name},
            small_picture => $small,
            large_picture => $large,
            created_at => $dt->strftime('%Y-%m-%d %H:%M:%S'),
        });
        $recommend_user = database->quick_select('recommend_users', {fb_user_id => $target->{'id'}});
    }

    my $recommend = database->quick_select('recommends', {user_id => $user->{'id'}, recommend_user_id => $recommend_user->{id}});
    if ($recommend) {

    }
    else {
        database->quick_insert('recommends', {
            user_id => $user->{id},
            recommend_user_id => $recommend_user->{id},
            recommend => param('recommend'),
            created_at => $dt->strftime('%Y-%m-%d %H:%M:%S'),
        });
        $recommend = database->quick_select('recommends', {user_id => $user->{'id'}, recommend_user_id => $recommend_user->{id}});

    }
    my @tags = split(/,/, param('user_tags'));
    for my $tag (@tags) {
        chomp $tag;
        $tag =~ s/^\s*(.*?)\s*$/$1/;
        database->quick_insert('user_tags', {
            recommend_user_id => $recommend_user->{id},
            recommend_id => $recommend->{id},
            tag => $tag,
            created_at => $dt->strftime('%Y-%m-%d %H:%M:%S'),
        });
    }
    my @ftags = split(/,/, param('user_fav_tags'));
    for my $ftag (@ftags) {
        chomp $ftag;
        $ftag =~ s/^\s*(.*?)\s*$/$1/;
        database->quick_insert('user_favorite_tags', {
            recommend_user_id => $recommend_user->{id},
            recommend_id => $recommend->{id},
            tag => $ftag,
            created_at => $dt->strftime('%Y-%m-%d %H:%M:%S'),
        });
    }
    my $str = param('recommend');
    fb->add_post
    ->set_message("Show Kindでお友達を「$str」とオススメしました。")
    ->set_link_uri(uri_for('/user/' . $recommend_user->{id}))
    ->set_link_name("Show Kind")
    ->set_link_caption("あの人の恋のキューピットになろう")
    ->set_link_description(
        "Show KindはFacebook上の友達の為に恋人や友人の輪を広げてあげるサービスです。" .
        "いい人なんだけど、なかなか出会いがない、そんなあの人をオススメしましょう！")
    ->publish;

    redirect uri_for('/complete/' . $target->{id});
};

get '/complete/:id' => sub {
    my $fb_user = session 'fb_user';
    fb->access_token($fb_user->{fb_access_token});

    my $id = param('id');
    my $target = fb->query->find($id)->select_fields(qw(id name gender picture))->request->as_hashref;

    template 'complete', {target => $target};
};

get '/user/:id' => sub {

    my $id = param('id');
    my $recommend_user = database->quick_select('recommend_users', {id => $id});
    my @recs = database->quick_select('recommends', {recommend_user_id => $id});
    my @recommends = ();
    foreach my $rec (@recs) {
        my $user = database->quick_select('users', {id => $rec->{user_id}});
        $rec->{user} = $user;
        push (@recommends, $rec);
    }

    my @user_tags = database->quick_select('user_tags', {recommend_user_id => $id});
    my $user_tag = tags2html(\@user_tags);

    my @fav_tags = database->quick_select('user_favorite_tags', {recommend_user_id => $id});
    my $fav_tag = tags2html(\@fav_tags);

    template 'user', {target => $recommend_user, recommends => \@recommends, user_tag => $user_tag, fav_tag => $fav_tag};
};

sub tags2html {
    my ($tags) = @_;
    my $cloud = HTML::TagCloud->new;

    foreach my $tag (@$tags) {
        $cloud->add_static($tag->{tag}, 1);
    }

    return $cloud->html_and_css(50);
}

true;
