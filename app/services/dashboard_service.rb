# frozen_string_literal: true

class DashboardService
  def initialize
    @current_time = Time.current
  end

  # Service object interface
  def call
    kpi_metrics
  end

  def kpi_metrics
    [
      todays_cost_data,
      yesterdays_cost_data,
      this_month_cost_data,
      last_month_cost_data,
      openrouter_credits_data
    ]
  rescue => e
    # Return placeholder metrics if there's an error
    [
      placeholder_metric("Today's Cost", "?", "green"),
      placeholder_metric("Yesterday's Cost", "?", "blue"),
      placeholder_metric("Total Cost (This Month)", "?", "purple"),
      placeholder_metric("Total Cost (Last Month)", "?", "yellow"),
      placeholder_metric("OpenRouter Credits", "?", "red")
    ]
  end

  def top_prompts_today
    AiLog.where(created_at: todays_range)
         .where.not(prompt_key: nil)
         .group(:prompt_key)
         .select("prompt_key, COUNT(*) as usage_count, AVG(duration_ms) as avg_duration_ms, AVG(total_cost) as avg_cost")
         .order("usage_count DESC")
         .limit(5)
         .map do |log|
           {
             prompt_name: log.prompt_key.truncate(50),
             usage_count: log.usage_count,
             avg_duration: format_duration(log.avg_duration_ms.to_f),
             avg_cost: format_cost(log.avg_cost.to_f)
           }
         end
  end

  def top_models_today
    AiLog.where(created_at: todays_range)
         .group(:model)
         .select("model, COUNT(*) as usage_count, AVG(duration_ms) as avg_duration_ms, SUM(total_cost) as total_cost")
         .order("usage_count DESC")
         .limit(5)
         .map do |log|
           {
             model: log.model,
             usage_count: log.usage_count,
             avg_duration: format_duration(log.avg_duration_ms.to_f),
             total_cost: format_cost(log.total_cost.to_f)
           }
         end
  end

  def format_duration(ms)
    return "0ms" if ms.zero?

    if ms < 1000
      "#{ms.round}ms"
    elsif ms < 60000
      "#{(ms / 1000).round(1)}s"
    else
      "#{(ms / 60000).round(1)}m"
    end
  end

  private

  def todays_cost_data
    cost = calculate_cost_for_period(todays_range)
    {
      value: cost,
      formatted: format_cost(cost),
      label: "Today's Cost",
      symbol: "$",
      color: "green"
    }
  end

  def yesterdays_cost_data
    cost = calculate_cost_for_period(yesterdays_range)
    {
      value: cost,
      formatted: format_cost(cost),
      label: "Yesterday's Cost",
      symbol: "$",
      color: "blue"
    }
  end

  def this_month_cost_data
    cost = calculate_cost_for_period(this_month_range)
    {
      value: cost,
      formatted: format_cost(cost),
      label: "Total Cost (This Month)",
      symbol: "$",
      color: "green"
    }
  end

  def last_month_cost_data
    cost = calculate_cost_for_period(last_month_range)
    {
      value: cost,
      formatted: format_cost(cost),
      label: "Total Cost (Last Month)",
      symbol: "$",
      color: "blue"
    }
  end

  def openrouter_credits_data
    credits = OpenrouterService.credits || 0
    {
      value: credits,
      formatted: format_credits(credits),
      label: "OpenRouter Credits",
      symbol: "$",
      color: "red"
    }
  end

  def placeholder_metric(label, value, color)
    {
      value: value,
      formatted: value,
      label: label,
      symbol: "",
      color: color
    }
  end

  def this_month_range
    @current_time.beginning_of_month..@current_time.end_of_month
  end

  def last_month_range
    1.month.ago.beginning_of_month..1.month.ago.end_of_month
  end

  def todays_range
    @current_time.beginning_of_day..@current_time.end_of_day
  end

  def yesterdays_range
    1.day.ago.beginning_of_day..1.day.ago.end_of_day
  end

  def calculate_cost_for_period(date_range)
    AiLog.where(created_at: date_range).sum(:total_cost) || 0
  end

  def format_cost(cost)
    return "0.00" unless cost&.positive?
    if cost >= 0.01
      '%.2f' % cost
    else
      return " > 0.01"
    end
  end

  def format_credits(credits)
    return "0.00" unless credits&.positive?
    '%.2f' % credits
  end
end
