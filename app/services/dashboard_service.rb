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
      this_month_cost_data,
      last_month_cost_data,
      placeholder_metric("Metric 3", "?", "purple"),
      placeholder_metric("Metric 4", "?", "yellow"),
      placeholder_metric("Metric 5", "?", "red")
    ]
  rescue => e
    # Return placeholder metrics if there's an error
    [
      placeholder_metric("Total Cost (This Month)", "?", "green"),
      placeholder_metric("Total Cost (Last Month)", "?", "blue"),
      placeholder_metric("Metric 3", "?", "purple"),
      placeholder_metric("Metric 4", "?", "yellow"),
      placeholder_metric("Metric 5", "?", "red")
    ]
  end

  private

  def this_month_cost_data
    cost = calculate_cost_for_period(this_month_range)
    {
      value: cost,
      formatted: "$#{format_cost(cost)}",
      label: "Total Cost (This Month)",
      symbol: "$",
      color: "green"
    }
  end

  def last_month_cost_data
    cost = calculate_cost_for_period(last_month_range)
    {
      value: cost,
      formatted: "$#{format_cost(cost)}",
      label: "Total Cost (Last Month)",
      symbol: "$",
      color: "blue"
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
end
