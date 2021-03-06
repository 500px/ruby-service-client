# This is based on this code: https://github.com/bitherder/stitch

require 'fiber'

module Px::Service::Client
  class Future
    class AlreadyCompletedError < StandardError; end

    ##
    # Create a new future. If a block is given, it is executed and the future is automatically completed
    # with the block's return value
    def initialize
      @completed = false
      @pending_calls = []

      if block_given?
        Fiber.new do
          value = begin
            yield
          rescue Exception => ex
            ex
          end
          complete(value)
        end.resume
      end
    end

    def complete(value)
      raise AlreadyCompletedError.new if @completed

      @value = value
      @completed = true
      @pending_calls.each do |pending_call|
        if value.kind_of?(Exception)
          pending_call[:fiber].resume(value)
        else
          result = nil
          begin
            if pending_call[:method]
              result = value.send(pending_call[:method], *pending_call[:args])
            else
              result = value
            end
          rescue Exception => ex
            result = ex
          end
          pending_call[:fiber].resume(result)
        end
      end
    end

    def value
      if @completed
        @value
      else
        wait_for_value(nil)
      end
    end

    def value!
      if @completed
        result = @value
      else
        result = wait_for_value(nil)
      end

      if result.kind_of?(Exception)
        # Set the backtrack properly to reflect where this method is called
        result.set_backtrace(caller)
        raise result
      end

      result
    end

    def completed?
      @completed
    end

    def method_missing(method, *args)
      if @completed
        if @value.kind_of?(Exception)
          # Set the backtrack properly to reflect where this method is called
          @value.set_backtrace(caller)
          raise @value
        end

        super unless respond_to_missing?(method)
        @value.send(method, *args)
      else
        result = wait_for_value(method, *args)
        raise result if result.kind_of?(Exception)
        result
      end
    end

    def respond_to_missing?(method, include_private = false)
      # NoMethodError is handled by method_missing here, so that exceptions
      # are raised properly even though they don't respond_to the same things
      # as the future values themselves
      true
    end

    private

    def wait_for_value(method, *args)
      # TODO: check for root fiber
      @pending_calls << { fiber: Fiber.current, method: method, args: args }
      Fiber.yield
    end
  end
end
