# frozen_string_literal: true

namespace :prompts do
  desc "Match existing AiLog records to prompts by content"
  task match_existing: :environment do
    puts "Starting prompt matching process..."

    # Get all prompts
    prompts = Prompt.active.pluck(:id, :name, :content)
    puts "Found #{prompts.count} active prompts"

    # Get ai_logs that don't have prompt_key set
    ai_logs = AiLog.where(prompt_key: nil)
    puts "Found #{ai_logs.count} AiLog records to process"

    matched_count = 0
    ai_logs.find_each do |ai_log|
      next unless ai_log.query.present?

      # Get first and last lines of the query
      query_lines = ai_log.query.strip.split("\n")
      first_line = query_lines.first&.strip
      last_line = query_lines.last&.strip

      next unless first_line && last_line

      # Find matching prompt
      matching_prompt = prompts.find do |prompt_id, prompt_name, prompt_content|
        next unless prompt_content.present?

        prompt_lines = prompt_content.strip.split("\n")
        prompt_first = prompt_lines.first&.strip
        prompt_last = prompt_lines.last&.strip

        # Match if first and last lines are the same
        first_line == prompt_first #&& last_line == prompt_last
      end

      if matching_prompt
        prompt_id, prompt_name, _ = matching_prompt
        ai_log.update(prompt_key: prompt_name)
        matched_count += 1
        puts "Matched AiLog #{ai_log.id} to prompt: #{prompt_name}" if matched_count % 100 == 0
      end
    end

    puts "Completed! Matched #{matched_count} AiLog records to prompts"
  end
end