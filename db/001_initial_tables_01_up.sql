CREATE TABLE users (
    id integer auto_increment, 
    fb_user_id varchar(256) NOT NULL,
    name varchar(256) NOT NULL,
    small_picture varchar(512),
    large_picture varchar(512),
    fb_access_token varchar(256) NOT NULL,
    created_at datetime NOT NULL,
    updated_at timestamp,
    primary key(id)
);

CREATE TABLE recommend_users (
    id integer auto_increment, 
    fb_user_id varchar(256) NOT NULL,
    name varchar(256) NOT NULL,
    small_picture varchar(512),
    large_picture varchar(512),
    created_at datetime NOT NULL,
    updated_at timestamp,
    primary key(id)
);

CREATE TABLE recommends (
    id integer auto_increment, 
    user_id integer,
    recommend_user_id integer,
    recommend varchar(256) NOT NULL,
    created_at datetime NOT NULL,
    updated_at timestamp,
    primary key(id)
);

CREATE TABLE user_tags(
    id integer auto_increment, 
    recommend_user_id integer NOT NULL,
    recommend_id integer NOT NULL,
    tag varchar(128) NOT NULL,
    created_at datetime NOT NULL,
    updated_at timestamp,
    primary key(id)
);

CREATE TABLE user_favorite_tags(
    id integer auto_increment, 
    recommend_user_id integer NOT NULL,
    recommend_id integer NOT NULL,
    tag varchar(128) NOT NULL,
    created_at datetime NOT NULL,
    updated_at timestamp,
    primary key(id)
);

