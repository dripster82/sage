# frozen_string_literal: true

namespace :pricing do
  desc "Fetch and update pricing for all allowed models from RubyLLM"
  task fetch_and_update: :environment do
    puts "Starting pricing fetch and update..."
    
    allowed_models = AllowedModel.all
    total = allowed_models.count
    updated = 0
    failed = 0
    
    if total.zero?
      puts "No allowed models found."
      return
    end
    
    allowed_models.each_with_index do |allowed_model, index|
      print "\r[#{index + 1}/#{total}] Processing #{allowed_model.name}..."
      
      begin
        # Find the RubyLLM model - try exact match first, then try matching the model ID part
        ruby_llm_model = RubyLLM.models.to_a.find { |m| m.id == allowed_model.model }

        # If not found, try matching just the model ID part (after the /)
        unless ruby_llm_model
          model_id_part = allowed_model.model.split('/').last
          ruby_llm_model = RubyLLM.models.to_a.find { |m| m.id == model_id_part }
        end
        
        unless ruby_llm_model
          puts "\n  ⚠️  RubyLLM model not found for: #{allowed_model.model}"
          failed += 1
          next
        end
        
        unless ruby_llm_model.pricing
          puts "\n  ⚠️  No pricing data available for: #{allowed_model.name}"
          failed += 1
          next
        end
        
        # Extract pricing
        input_price = ruby_llm_model.pricing.text_tokens&.input
        output_price = ruby_llm_model.pricing.text_tokens&.output
        
        unless input_price && output_price
          puts "\n  ⚠️  Incomplete pricing data for: #{allowed_model.name}"
          failed += 1
          next
        end
        
        # Update the model directly using assignment and save
        allowed_model.pricing_input = input_price
        allowed_model.pricing_output = output_price
        allowed_model.save!
        
        updated += 1
      rescue StandardError => e
        puts "\n  ❌ Error processing #{allowed_model.name}: #{e.message}"
        puts "     Backtrace: #{e.backtrace.first(3).join("\n     ")}"
        failed += 1
      end
    end
    
    puts "\n\n✅ Pricing update complete!"
    puts "  Updated: #{updated}"
    puts "  Failed: #{failed}"
    puts "  Total: #{total}"
  end
end

