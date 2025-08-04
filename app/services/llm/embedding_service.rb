module Llm
  class EmbeddingService
    # Alias for embed_chunks to satisfy service object interface
    def call(chunks)
      embed_chunks(chunks)
    end

    def embed_chunks(chunks)
      # ensure that using threads does not exceed the rate limit
      
      max_threads =  ENV.fetch('EMBEDDING_THREADS', 5).to_i
      max_per_minute = ENV.fetch('EMBEDDING_RPM', 120).to_i
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
            chunk.vector = embed_text(chunk.text)
          ensure
            semaphore.pop       # release slot
          end
        end
      end

      threads.each(&:join)

      chunks
    end

    def embed_text(text)
      RubyLLM.embed(text)
    end
  end
end