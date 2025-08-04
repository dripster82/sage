# frozen_string_literal: true

require 'rails_helper'

RSpec.describe DashboardService, type: :service do
  let(:service) { DashboardService.new }

  it_behaves_like 'a service object'

  describe 'initialization' do
    it 'sets current_time' do
      freeze_time do
        service = DashboardService.new
        expect(service.instance_variable_get(:@current_time)).to eq(Time.current)
      end
    end
  end

  describe '#kpi_metrics' do
    let!(:this_month_logs) { create_list(:ai_log, 3, created_at: 1.week.ago) }
    let!(:last_month_logs) { create_list(:ai_log, 2, created_at: 1.month.ago) }

    it 'returns array of 5 metrics' do
      metrics = service.kpi_metrics
      expect(metrics).to be_an(Array)
      expect(metrics.size).to eq(5)
    end

    it 'returns metrics with required structure' do
      metrics = service.kpi_metrics
      
      metrics.each do |metric|
        expect(metric).to have_key(:value)
        expect(metric).to have_key(:formatted)
        expect(metric).to have_key(:label)
        expect(metric).to have_key(:symbol)
        expect(metric).to have_key(:color)
      end
    end

    describe 'this month cost metric' do
      it 'has correct structure' do
        metric = service.kpi_metrics.first
        
        expect(metric[:label]).to eq('Total Cost (This Month)')
        expect(metric[:symbol]).to eq('$')
        expect(metric[:color]).to eq('green')
        expect(metric[:value]).to be_a(Numeric)
        expect(metric[:formatted]).to be_a(String)
      end

      it 'calculates cost for current month' do
        # Mock the private method to test calculation
        allow(service).to receive(:calculate_cost_for_period).and_return(123.45)
        
        metric = service.kpi_metrics.first
        expect(metric[:value]).to eq(123.45)
        expect(metric[:formatted]).to include('123.45')
      end
    end

    describe 'last month cost metric' do
      it 'has correct structure' do
        metric = service.kpi_metrics[1]
        
        expect(metric[:label]).to eq('Total Cost (Last Month)')
        expect(metric[:symbol]).to eq('$')
        expect(metric[:color]).to eq('blue')
        expect(metric[:value]).to be_a(Numeric)
        expect(metric[:formatted]).to be_a(String)
      end
    end

    describe 'placeholder metrics' do
      it 'returns placeholder metrics for remaining slots' do
        metrics = service.kpi_metrics[2..4]
        
        metrics.each_with_index do |metric, index|
          expect(metric[:label]).to eq("Metric #{index + 3}")
          expect(metric[:value]).to eq('?')
          expect(metric[:formatted]).to eq('?')
          expect(metric[:symbol]).to eq('')
        end
      end

      it 'has different colors for placeholder metrics' do
        colors = service.kpi_metrics[2..4].map { |m| m[:color] }
        expect(colors).to eq(['purple', 'yellow', 'red'])
      end
    end
  end

  describe 'private methods' do
    describe '#this_month_cost_data' do
      it 'calculates this month cost' do
        allow(service).to receive(:calculate_cost_for_period).with(anything).and_return(100.0)
        allow(service).to receive(:this_month_range).and_return(Time.current.beginning_of_month..Time.current.end_of_month)
        
        result = service.send(:this_month_cost_data)
        
        expect(result[:value]).to eq(100.0)
        expect(result[:label]).to eq('Total Cost (This Month)')
        expect(result[:color]).to eq('green')
      end
    end

    describe '#last_month_cost_data' do
      it 'calculates last month cost' do
        allow(service).to receive(:calculate_cost_for_period).with(anything).and_return(75.0)
        allow(service).to receive(:last_month_range).and_return(1.month.ago.beginning_of_month..1.month.ago.end_of_month)
        
        result = service.send(:last_month_cost_data)
        
        expect(result[:value]).to eq(75.0)
        expect(result[:label]).to eq('Total Cost (Last Month)')
        expect(result[:color]).to eq('blue')
      end
    end

    describe '#placeholder_metric' do
      it 'creates placeholder metric with given parameters' do
        result = service.send(:placeholder_metric, 'Test Metric', 'N/A', 'orange')
        
        expect(result[:label]).to eq('Test Metric')
        expect(result[:value]).to eq('N/A')
        expect(result[:formatted]).to eq('N/A')
        expect(result[:symbol]).to eq('')
        expect(result[:color]).to eq('orange')
      end
    end

    describe '#calculate_cost_for_period' do
      let(:period) { 1.week.ago..Time.current }

      before do
        # Create AI logs with token data for cost calculation
        create(:ai_log, input_tokens: 1000, output_tokens: 500, created_at: 3.days.ago)
        create(:ai_log, input_tokens: 2000, output_tokens: 1000, created_at: 5.days.ago)
        create(:ai_log, input_tokens: 500, output_tokens: 250, created_at: 2.months.ago) # Outside period
      end

      it 'calculates cost for logs in period' do
        # This would test the actual cost calculation logic
        # The implementation would need to be added to the service
        cost = service.send(:calculate_cost_for_period, period)
        expect(cost).to be_a(Numeric)
        expect(cost).to be >= 0
      end

      it 'returns 0 for period with no logs' do
        future_period = 1.week.from_now..2.weeks.from_now
        cost = service.send(:calculate_cost_for_period, future_period)
        expect(cost).to eq(0)
      end
    end

    describe '#format_cost' do
      it 'formats cost with 2 decimal places' do
        formatted = service.send(:format_cost, 123.456)
        expect(formatted).to eq('123.46')
      end

      it 'formats zero cost' do
        formatted = service.send(:format_cost, 0)
        expect(formatted).to eq('0.00')
      end

      it 'formats large costs' do
        formatted = service.send(:format_cost, 1234.56)
        expect(formatted).to eq('1234.56')
      end
    end

    describe '#this_month_range' do
      it 'returns current month range' do
        freeze_time do
          range = service.send(:this_month_range)
          expected_start = Time.current.beginning_of_month
          expected_end = Time.current.end_of_month
          
          expect(range.begin).to eq(expected_start)
          expect(range.end).to eq(expected_end)
        end
      end
    end

    describe '#last_month_range' do
      it 'returns last month range' do
        freeze_time do
          range = service.send(:last_month_range)
          expected_start = 1.month.ago.beginning_of_month
          expected_end = 1.month.ago.end_of_month
          
          expect(range.begin).to eq(expected_start)
          expect(range.end).to eq(expected_end)
        end
      end
    end
  end

  describe 'integration with AiLog model' do
    it 'works with real AiLog data' do
      # Create some real AI logs
      create_list(:ai_log, 5, :with_high_tokens, created_at: 1.week.ago)
      
      expect {
        metrics = service.kpi_metrics
        expect(metrics).to be_present
      }.not_to raise_error
    end
  end

  describe 'error handling' do
    it 'handles database errors gracefully' do
      allow(AiLog).to receive(:where).and_raise(ActiveRecord::ConnectionNotEstablished)
      
      expect {
        service.kpi_metrics
      }.not_to raise_error
    end
  end

  describe 'performance' do
    it 'performs efficiently with large datasets' do
      # Create many AI logs
      create_list(:ai_log, 100, created_at: 1.week.ago)
      
      expect {
        Timeout.timeout(5) do
          service.kpi_metrics
        end
      }.not_to raise_error
    end
  end
end
