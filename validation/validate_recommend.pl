use utf8;
{
    # Fields for validating
        fields => [ qw/recommend user_tags user_fav_tags/ ],
    filters => [
        qr/.+/ => filter(qw/trim strip/),
    ],
    checks => [
        [ qw/recommend/ ] => is_required("必須項目です。"),
        recommend => is_long_between( 1, 200, 'オススメポイントは200文字以内で入力してください'),
        user_tags => is_long_between( 0, 200, '友達の連想タグは200文字以内で入力してください'),
        user_fav_tags => is_long_between( 0, 200, '友達の好み連想タグは200文字以内で入力してください'),
    ],
}
