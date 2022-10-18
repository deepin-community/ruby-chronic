$: << 'lib' << 'test' << '.'
Dir['test/test_*.rb'].each { |f| require f }
