namespace :numbers do
  desc "Generate metrics based on user data and saves it to ./numbers.csv"
  task generate_csv: :environment do
    Numbers::NumbersCsv.generate
  end
end
