function claude
    if test (count $argv) -ge 1 -a "$argv[1]" = "go"
        command claude --dangerously-skip-permissions $argv[2..]
    else
        command claude $argv
    end
end
