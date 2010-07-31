SPEC_COMMAND = "mspec -t macruby ./spec"

desc "Run the specs"
task :spec do
  sh SPEC_COMMAND
end

desc "Run the specs with Kicker"
task :kick do
  sh "kicker -c -e '#{SPEC_COMMAND}'"
end

task :default => :spec
