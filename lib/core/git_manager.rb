class GitManager
  def self.create_branch(task_id, task_description = nil)
    # Default to main or master as base branch
    base = `git rev-parse --verify main >/dev/null 2>&1 && echo main || echo master`.strip

    slug = if task_description
             task_description.downcase.gsub(/[^a-z0-9]/, '-').gsub(/-+/, '-').slice(0, 40).strip.gsub(/^-|-$/, '')
           end
    branch_name = slug ? "task-#{task_id}-#{slug}" : "task-#{task_id}"

    # Branch from the base branch to keep a flat history
    `git checkout -b #{branch_name} #{base}`
  end

  def self.commit_changes(task_id, task_description)
    `git add .`
    `git commit -m "ares: task-#{task_id} #{task_description}"`
  end
end
