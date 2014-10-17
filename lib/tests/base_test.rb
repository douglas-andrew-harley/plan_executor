module Crucible
  module Tests
    class BaseTest

      def initialize(client)
        @client = client
      end

      def execute
        result = {}
        self.methods.grep(/_test$/).each do |test_method|
          puts "executing: #{test_method}..."
          begin
            content = self.method(test_method).call()
            status = 'passed'
          rescue => e
            content = "#{test_method} failed. Error: #{e.message}."
            if e.message.include? 'Implementation missing'
              status = 'missing'
            else
              status = 'failed'
            end
          end
          result[test_method] = {
            test_method: test_method,
            status: status,
            result: content
          }
        end
        result
      end

      def description
        self.class.name
      end

      def author
        self.class.name
      end

      def title
        self.class.name.split('::').last
      end

      def tests
        self.methods.grep(/_test$/)
      end

      # timestamp?

    end
  end
end