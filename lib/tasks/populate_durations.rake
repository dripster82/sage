# frozen_string_literal: true

namespace :ai_logs do
  desc "Populate duration_ms field for existing AiLog records"
  task populate_durations: :environment do
    puts "Starting duration population process..."

    # Get ai_logs that don't have duration_ms set
    ai_logs = AiLog.where(duration_ms: nil)
    puts "Found #{ai_logs.count} AiLog records to process"

    updated_count = 0
    ai_logs.find_each do |ai_log|
      if ai_log.completed?
        # Calculate duration in milliseconds
        duration_ms = ((ai_log.updated_at - ai_log.created_at) * 1000).to_i
        ai_log.update(duration_ms: duration_ms)
        updated_count += 1
        puts "Updated AiLog #{ai_log.id} with duration: #{duration_ms}ms" if updated_count % 100 == 0
      end
    end

    puts "Completed! Updated #{updated_count} AiLog records with duration data"
  end
end