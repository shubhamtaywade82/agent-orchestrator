require "yaml"

class ContextLoader
  CONFIG_PATH = File.expand_path("../../config/workspaces.yml", __dir__)

  def self.load
    root = find_workspace_root(Dir.pwd)

    agents_file = File.join(root, "AGENTS.md")
    skills_dir  = File.join(root, ".skills")

    agents = File.exist?(agents_file) ? File.read(agents_file) : ""
    skills = ""

    if Dir.exist?(skills_dir)
      Dir.glob(File.join(skills_dir, "**/SKILL.md")).each do |file|
        skills += File.read(file) + "\n"
      end
    end

    "Workspace Root: #{root}\n#{agents}\n#{skills}"
  end

  private

  def self.find_workspace_root(path)
    # Check explicitly registered workspaces first
    if File.exist?(CONFIG_PATH)
      registered = YAML.load_file(CONFIG_PATH)["workspaces"] || []
      registered.each do |workspace|
        return workspace if path.start_with?(workspace)
      end
    end

    # Walk up the tree looking for AGENTS.md
    current = path
    while current != "/"
      return current if File.exist?(File.join(current, "AGENTS.md"))
      current = File.expand_path("..", current)
    end

    path # Default to CWD if no root found
  end
end
