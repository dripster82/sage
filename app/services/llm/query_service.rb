module Llm
  class QueryService
    def query_prompts(prompts)
      # ensure that using threads does not exceed the rate limit
      
      max_threads =  ENV.fetch('LLM_QUERY_THREADS', 5).to_i
      max_per_minute = ENV.fetch('LLM_QUERY_RPM', 20).to_i
      interval = 60.0 / max_per_minute
      semaphore = SizedQueue.new(max_threads)
      last_call_time = Mutex.new
      last_time = Time.at(0)

      threads = chunks.map do |chunk|
        Thread.new do
          semaphore.push(true)  # acquire slot
          begin
            last_call_time.synchronize do
              now = Time.now
              elapsed = now - last_time
              if elapsed < interval
                sleep(interval - elapsed)
              end
              last_time = Time.now
            end
            chunk.vector = RubyLLM.embed(chunk.text)
          ensure
            semaphore.pop       # release slot
          end
        end
      end

      threads.each(&:join)

      chunks
    end
  end
end