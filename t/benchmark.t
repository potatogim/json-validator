BEGIN { $ENV{JSON_VALIDATOR_WARN_MISSING_FORMAT} = 0 }
use Mojo::Base -strict;
use Benchmark qw(cmpthese timeit :hireswallclock);
use JSON::Validator::Schema::Draft7;
use List::Util qw(sum);
use Test::More;
use Time::HiRes qw(time);

plan skip_all => 'TEST_BENCHMARK=500' unless my $n = $ENV{TEST_BENCHMARK};
diag sprintf "\n%s", scalar localtime;
diag "n_times=$n";

my %bm;
time_schema('defaults'       => {});
time_schema('resolve_before' => {resolve_before => 1});
cmpthese \%bm if $ENV{HARNESS_IS_VERBOSE};

done_testing;

sub time_schema {
  my ($desc, $attrs) = @_;
  my (@errors, @resolve_t, @validate_t, @total_t);

  my $resolve_before = delete $attrs->{resolve_before};
  my $resolved_schema
    = $resolve_before && JSON::Validator::Schema::Draft7->new('http://json-schema.org/draft-07/schema#', %$attrs);

  $bm{$desc} = timeit 1 => sub {
    for (1 ... $n) {
      my $schema = $resolved_schema || JSON::Validator::Schema::Draft7->new(%$attrs);

      my $t0 = time;
      delete $schema->{errors};
      $schema->data('http://json-schema.org/draft-07/schema#')->resolve unless $resolve_before;
      push @resolve_t, (my $t1 = time) - $t0;

      push @errors, @{$schema->errors};
      push @validate_t, (my $t2 = time) - $t1;

      push @total_t, $t2 - $t0;
    }
  };

  ok !@errors, 'valid schema' or diag "@errors";

  my $rt = sprintf '%.3f', sum @resolve_t;
  ok $rt < 2, "$desc - resolve ${rt}s" unless $resolve_before;

  my $vt = sprintf '%.3f', sum @validate_t;
  ok $vt < 2, "$desc - validate ${vt}s";

  my $tt = sprintf '%.3f', sum @total_t;
  ok $tt < 2, "$desc - total ${tt}s";
}

__DATA__
# Mon Jul 19 10:38:47 2021
# n_times=200

ok 1 - valid schema
ok 2 - defaults - resolve 0.548s
not ok 3 - defaults - validate 2.052s
not ok 4 - defaults - total 2.600s

#   Failed test 'defaults - validate 2.052s'
#   at t/benchmark.t line 50.

#   Failed test 'defaults - total 2.600s'
#   at t/benchmark.t line 53.
ok 5 - valid schema
not ok 6 - resolve_before - validate 2.078s

#   Failed test 'resolve_before - validate 2.078s'
#   at t/benchmark.t line 50.
not ok 7 - resolve_before - total 2.078s

#   Failed test 'resolve_before - total 2.078s'
#   at t/benchmark.t line 53.
               s/iter       defaults resolve_before
defaults         2.59             --           -20%
resolve_before   2.07            25%             --
