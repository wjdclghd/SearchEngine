warn("PR에 description을 작성해 주세요") if github.pr_body.strip.empty?

fail("테스트가 실행되지 않았습니다") unless git.modified_files.any? { |f| f.include?("Tests") }

warn("README 변경 감지!") if git.modified_files.include?("README.md")

unless github.pr_title.downcase.include?("[wip]")
  coverage = ENV['COVERAGE'] || '0'
  message = "Code coverage is #{coverage.to_f.round(2)}%"
  if coverage.to_f < 50
    warn("#{message} - 커버리지가 낮습니다.")
  else
    message("#{message} - 충분한 커버리지입니다.")
  end
end