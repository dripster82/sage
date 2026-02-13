# frozen_string_literal: true

ActiveAdmin.register_page "Dashboard" do
  menu priority: 1, label: proc { I18n.t("active_admin.dashboard") }

  content title: proc { I18n.t("active_admin.dashboard") } do
    # Get dashboard metrics
    dashboard = DashboardService.new
    kpi_metrics = dashboard.kpi_metrics
    top_prompts = dashboard.top_prompts_today
    top_models = dashboard.top_models_today

    # Render KPI boxes using shared partial
    render partial: 'shared/kpi_boxes', locals: { kpi_metrics: kpi_metrics }

    # Two Column Layout
    div class: "grid grid-cols-1 lg:grid-cols-2 gap-8" do
      # Left Column
      div do
        # Top Prompts Today
        div class: "bg-white dark:bg-gray-800 overflow-hidden shadow rounded-lg border border-gray-200 dark:border-gray-700 mb-6" do
          div class: "px-4 py-5 sm:p-6" do
            h3 "Top 5 Prompts Today", class: "text-lg leading-6 font-medium text-gray-900 dark:text-gray-100"
            div class: "mt-4" do
              if top_prompts.any?
                table class: "min-w-full divide-y divide-gray-200 dark:divide-gray-700" do
                  thead class: "bg-gray-50 dark:bg-gray-700" do
                    tr do
                      th "Prompt", class: "px-6 py-3 text-left text-xs font-medium text-gray-500 dark:text-gray-300 uppercase tracking-wider"
                      th "Usage", class: "px-6 py-3 text-left text-xs font-medium text-gray-500 dark:text-gray-300 uppercase tracking-wider"
                      th "Avg Duration", class: "px-6 py-3 text-left text-xs font-medium text-gray-500 dark:text-gray-300 uppercase tracking-wider"
                      th "Avg Cost", class: "px-6 py-3 text-left text-xs font-medium text-gray-500 dark:text-gray-300 uppercase tracking-wider"
                    end
                  end
                  tbody class: "bg-white dark:bg-gray-800 divide-y divide-gray-200 dark:divide-gray-700" do
                    top_prompts.each do |prompt|
                      tr do
                        td prompt[:prompt_name], class: "px-6 py-4 whitespace-nowrap text-sm text-gray-900 dark:text-gray-100"
                        td prompt[:usage_count], class: "px-6 py-4 whitespace-nowrap text-sm text-gray-500 dark:text-gray-400"
                        td prompt[:avg_duration], class: "px-6 py-4 whitespace-nowrap text-sm text-gray-500 dark:text-gray-400"
                        td "$#{prompt[:avg_cost]}", class: "px-6 py-4 whitespace-nowrap text-sm text-gray-500 dark:text-gray-400"
                      end
                    end
                  end
                end
              else
                div class: "text-sm text-gray-500 dark:text-gray-400" do
                  para "No prompts used today."
                end
              end
            end
          end
        end

        # Placeholder Box 2
        div class: "bg-white dark:bg-gray-800 overflow-hidden shadow rounded-lg border border-gray-200 dark:border-gray-700 mb-6" do
          div class: "px-4 py-5 sm:p-6" do
            h3 "Left Column - Box 2", class: "text-lg leading-6 font-medium text-gray-900 dark:text-gray-100"
            div class: "mt-2 max-w-xl text-sm text-gray-500 dark:text-gray-400" do
              para "TBA - Content placeholder for future dashboard component."
            end
          end
        end
      end

      # Right Column
      div do
        # Top Models Today
        div class: "bg-white dark:bg-gray-800 overflow-hidden shadow rounded-lg border border-gray-200 dark:border-gray-700 mb-6" do
          div class: "px-4 py-5 sm:p-6" do
            h3 "Top 5 AI Models Today", class: "text-lg leading-6 font-medium text-gray-900 dark:text-gray-100"
            div class: "mt-4" do
              if top_models.any?
                table class: "min-w-full divide-y divide-gray-200 dark:divide-gray-700" do
                  thead class: "bg-gray-50 dark:bg-gray-700" do
                    tr do
                      th "Model", class: "px-6 py-3 text-left text-xs font-medium text-gray-500 dark:text-gray-300 uppercase tracking-wider"
                      th "Usage", class: "px-6 py-3 text-left text-xs font-medium text-gray-500 dark:text-gray-300 uppercase tracking-wider"
                      th "Avg Duration", class: "px-6 py-3 text-left text-xs font-medium text-gray-500 dark:text-gray-300 uppercase tracking-wider"
                      th "Total Cost", class: "px-6 py-3 text-left text-xs font-medium text-gray-500 dark:text-gray-300 uppercase tracking-wider"
                    end
                  end
                  tbody class: "bg-white dark:bg-gray-800 divide-y divide-gray-200 dark:divide-gray-700" do
                    top_models.each do |model|
                      tr do
                        td model[:model], class: "px-6 py-4 whitespace-nowrap text-sm text-gray-900 dark:text-gray-100"
                        td model[:usage_count], class: "px-6 py-4 whitespace-nowrap text-sm text-gray-500 dark:text-gray-400"
                        td model[:avg_duration], class: "px-6 py-4 whitespace-nowrap text-sm text-gray-500 dark:text-gray-400"
                        td "$#{model[:total_cost]}", class: "px-6 py-4 whitespace-nowrap text-sm text-gray-500 dark:text-gray-400"
                      end
                    end
                  end
                end
              else
                div class: "text-sm text-gray-500 dark:text-gray-400" do
                  para "No models used today."
                end
              end
            end
          end
        end

        # Placeholder Box 4
        div class: "bg-white dark:bg-gray-800 overflow-hidden shadow rounded-lg border border-gray-200 dark:border-gray-700 mb-6" do
          div class: "px-4 py-5 sm:p-6" do
            h3 "Right Column - Box 2", class: "text-lg leading-6 font-medium text-gray-900 dark:text-gray-100"
            div class: "mt-2 max-w-xl text-sm text-gray-500 dark:text-gray-400" do
              para "TBA - Content placeholder for future dashboard component."
            end
          end
        end
      end
    end
  end
end
