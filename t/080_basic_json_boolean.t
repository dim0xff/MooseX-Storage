use strict;
use warnings;

use Test::More;
use Test::Deep;
use Test::Deep::Type;
use Test::Fatal;
use Moose::Util::TypeConstraints;
use JSON::PP;
use MooseX::Storage::Engine;

MooseX::Storage::Engine->add_custom_type_handler(
    'JSON::PP::Boolean' => (
        expand   => sub { $_[0]{__value} ? JSON::PP::true : JSON::PP::false },
        collapse => sub { { __CLASS__ => 'JSON::PP::Boolean', __value => "$_[0]" } },
    )
);

# support for this was tentatively added in v0.49, but there were unwanted
# side effects, and the tests in this file do not pass even with those changes.
#local $TODO = 'ability to pack/unpack nested objects is not quite functional';

{
    package Foo;
    use Moose;
    use MooseX::Storage;

    with Storage;

    has 'one_bool' => (
        is => 'ro',
        isa => 'JSON::PP::Boolean',
    );

    has 'many_bools' => (
        is  => 'ro',
        isa => 'ArrayRef[JSON::PP::Boolean]'
    );

    has 'hash_bools' => (
        is  => 'ro',
        isa => 'HashRef[JSON::PP::Boolean]'
    );
}

{
    my $foo = Foo->new(
        one_bool => JSON::PP::true,
        many_bools => [ JSON::PP::false, JSON::PP::true ],
        hash_bools => { true => JSON::PP::true, false => JSON::PP::false },
    );

    isa_ok($foo, 'Foo');

    my $pack_result;
    is(
        exception { $pack_result = $foo->pack },
        undef,
        'packing completed successfully',
    );

    cmp_deeply(
        $pack_result,
        {
            __CLASS__ => 'Foo',
            one_bool => { __CLASS__ => 'JSON::PP::Boolean', __value => 1 },
            many_bools => [ { __CLASS__ => 'JSON::PP::Boolean', __value => 0 } , { __CLASS__ => 'JSON::PP::Boolean', __value => 1 } ],
            hash_bools => { false => { __CLASS__ => 'JSON::PP::Boolean', __value => 0 } , true => { __CLASS__ => 'JSON::PP::Boolean', __value => 1 } },
        },
        '... got the right frozen structure'
    );
}

{
    my $foo;
    is(
        exception {
            $foo = Foo->unpack(
                {
                    __CLASS__ => 'Foo',
                    one_bool => { __CLASS__ => 'JSON::PP::Boolean', __value => 1 },
                    many_bools => [ { __CLASS__ => 'JSON::PP::Boolean', __value => 0 } , { __CLASS__ => 'JSON::PP::Boolean', __value => 1 } ],
                    hash_bools => { false => { __CLASS__ => 'JSON::PP::Boolean', __value => 0 } , true => { __CLASS__ => 'JSON::PP::Boolean', __value => 1 } },
                },
            )
        },
        undef,
        'unpacking completed successfully',
    );

    isa_ok($foo, 'Foo') && do {
        cmp_deeply(
            $foo->one_bool,
            all(is_type(class_type('JSON::PP::Boolean')), JSON::PP::true),
            'one_bool attr is correct',
        );


        cmp_deeply(
            $foo->many_bools,
            [
                all(is_type(class_type('JSON::PP::Boolean')), JSON::PP::false),
                all(is_type(class_type('JSON::PP::Boolean')), JSON::PP::true),
            ],
            'many_bools attr is correct',
        );

        cmp_deeply(
            $foo->hash_bools,
            {
                false => all(is_type(class_type('JSON::PP::Boolean')), JSON::PP::false),
                true  => all(is_type(class_type('JSON::PP::Boolean')), JSON::PP::true),
            },
            'hash_bools attr is correct',
        );
    };
}

done_testing;
