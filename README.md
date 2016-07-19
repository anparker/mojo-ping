# Mojo::Ping

Check host availability using Mojo.

```perl

use Mojo::Ping;

my $ping = Mojo::Ping->new('ICMP');
say 'Host is up!' if $ping->ping('localhost');

    
# or

$ping->ping('host1.local' => sub {
    my ($backend, $avail, $err) = @_;
    ...
});
$ping->ping('host2.local' => sub { ... });
$ping->ping('host3.local' => sub { ... });
Mojo::IOLoop->start() unless Mojo::IOLoop->is_running;

```

