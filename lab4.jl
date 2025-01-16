function check_regex_syntax(regex::String)
    max_capturing_groups = 9
    capturing_groups_count = Ref(0)  # Счётчик групп захвата
    defined_groups = Set{Int}()  # Набор определённых групп захвата

    function parse_rg(s::String, inside_lookahead::Bool=false)
        if isempty(s)
            return true
        end
        # Проверка на символы [a-z]
        if occursin(r"^[a-z]", s)
            return parse_rg(s[2:end], inside_lookahead)
        end
        # Проверка на опережающие проверки (?=...)
        if occursin(r"^\(\?=", s)
            depth = 1
            lookahead_content = ""
            for i in 4:length(s)
                if s[i] == '('
                    depth += 1
                elseif s[i] == ')'
                    depth -= 1
                end
                if depth == 0
                    lookahead_content = s[4:i-1]
                    break
                end
            end
            if isempty(lookahead_content)
                return false
            end
            # Внутри опережающих проверок запрещены группы захвата и вложенные опережающие проверки
            if !parse_rg(lookahead_content, true) || capturing_groups_count[] > 0
                return false
            end
            return parse_rg(s[length(lookahead_content)+5:end], inside_lookahead)
        end
        # Проверка на ссылки на группы захвата (?num)
        if occursin(r"^\(\?\d\)", s)
            num = parse(Int, s[3])
            if !(num in defined_groups)
                return false
            end
            return parse_rg(s[5:end], inside_lookahead)
        end
        # Проверка на группы захвата (group)
        if occursin(r"^\(", s)
            depth = 1
            group_content = ""
            for i in 2:length(s)
                if s[i] == '('
                    depth += 1
                elseif s[i] == ')'
                    depth -= 1
                end
                if depth == 0
                    group_content = s[2:i-1]
                    break
                end
            end
            if isempty(group_content)
                return false
            end
            # Обычные группы увеличивают счётчик
            if !inside_lookahead
                capturing_groups_count[] += 1
                if capturing_groups_count[] > max_capturing_groups
                    return false
                end
                push!(defined_groups, capturing_groups_count[])
            end
            return parse_rg(group_content, inside_lookahead) && parse_rg(s[length(group_content)+3:end], inside_lookahead)
        end
        # Проверка на операторы | и *
        if occursin(r"^\|", s) || occursin(r"^\*", s)
            return parse_rg(s[2:end], inside_lookahead)
        end
        return false
    end
    return parse_rg(regex)
end

examples = ["(a(?=(b)))", "((abc)*)(?1)", "(a(?1))", "(a|(bb))(a|(?3))", "(a(?1)b|c)", "(aa|bb)(?1)", "(a(b(c)))", "(((((a)))))", "(()", "a(b)c)"]
for example in examples
    if check_regex_syntax(example)
        println("Синтаксис регулярного выражения \"$example\" корректен.")
    else
        println("Синтаксис регулярного выражения \"$example\" некорректен.")
    end
end
