use Module::Build;
my $build = Module::Build->new
  (
   module_name => 'UrlDetails',
   license  => 'gpl3',
   requires => {
     'perl'          => '5.14.0',
     'HTTP::Tiny'  => '0.022',
     'Number::Format' => '1.73',
     'Time::Duration' => '1.06',
     'XML::Simple' => '2.20',
   },
   test_requires => {
     'File::Slurp' => '9999.19',
     'Test::MockObject' => '1.20120301',
   },
  );
$build->create_build_script;
