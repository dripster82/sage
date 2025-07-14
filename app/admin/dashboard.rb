# frozen_string_literal: true

ActiveAdmin.register_page "Dashboard" do
  menu priority: 1, label: proc { I18n.t("active_admin.dashboard") }

  content title: proc { I18n.t("active_admin.dashboard") } do
    # Get dashboard metrics
    dashboard = DashboardService.new
    kpi_metrics = dashboard.kpi_metrics

    # Render KPI boxes using shared partial
    render partial: 'shared/kpi_boxes', locals: { kpi_metrics: kpi_metrics }

    # Two Column Layout
    div class: "grid grid-cols-1 lg:grid-cols-2 gap-8" do
      # Left Column
      div do
        # Placeholder Box 1
        div class: "bg-white dark:bg-gray-800 overflow-hidden shadow rounded-lg border border-gray-200 dark:border-gray-700 mb-6" do
          div class: "px-4 py-5 sm:p-6" do
            h3 "Left Column - Box 1", class: "text-lg leading-6 font-medium text-gray-900 dark:text-gray-100"
            div class: "mt-2 max-w-xl text-sm text-gray-500 dark:text-gray-400" do
              para "TBA - Content placeholder for future dashboard component."
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
        # Placeholder Box 3
        div class: "bg-white dark:bg-gray-800 overflow-hidden shadow rounded-lg border border-gray-200 dark:border-gray-700 mb-6" do
          div class: "px-4 py-5 sm:p-6" do
            h3 "Right Column - Box 1", class: "text-lg leading-6 font-medium text-gray-900 dark:text-gray-100"
            div class: "mt-2 max-w-xl text-sm text-gray-500 dark:text-gray-400" do
              para "TBA - Content placeholder for future dashboard component."
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
