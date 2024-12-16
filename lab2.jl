using JSON, HTTP

const ALPHABET = Set("$d" for d ∈ 0:9) ∪ ["ε"]

S = ["ε"]
E = ["ε"]
Σ = collect(delete!(copy(ALPHABET), "ε"))

table = Dict()

suffixes_of(ω) = [ω[i:lastindex(ω)] for i ∈ eachindex(ω)]

payload = JSON.json(Dict("mode" => "normal"))
                         #"size" => 20))
println(payload)
response = HTTP.post("http://localhost:8080/generate", 
                         body=payload, 
                         headers=["Content-Type" => "application/json"])


function membership(ω)
    payload = JSON.json(Dict("word" => ω))
    response = HTTP.post("http://localhost:8080/checkWord", 
                            body=payload, 
                            headers=["Content-Type" => "application/json"])
    if response.status == 200
        result = JSON.parse(String(response.body))
        return result["response"] == "1" ? true : false
    end
    @error "Error occured while handling connection"
end

function print_table()
    prefixes = unique(vcat(S, Σ))
    suffixes = unique(E)

    println("       ", join(suffixes, " | "))
    println("-" ^ (15 + length(suffixes) * 5))

    for p ∈ prefixes
        row = []
        for s ∈ suffixes
            value = get(table, (p, s), false) 
            push!(row, value ? "1" : "0") 
        end

        println(p, "      | ", join(row, " | "))
    end
end

function equivalence(table)
    main_prefixes = collect(S)
    non_main_prefixes = collect(Σ)
    suffixes = collect(E)
    table_new = join((table[p, s] == true ? "1" : "0" for s ∈ suffixes, p ∈ vcat(main_prefixes, non_main_prefixes)), " ")
    json_data = JSON.json(Dict(
        "main_prefixes" => join(main_prefixes, " "),
        "non_main_prefixes" => join(non_main_prefixes, " "),
        "suffixes" => join(suffixes, " "),
        "table" => table_new 
    ))
    response = HTTP.post("http://localhost:8080/checkTable", 
                            body=json_data, 
                            headers=["Content-Type" => "application/json"])
    if response.status == 200
        result = JSON.parse(String(response.body))
        println(result)
        return result["response"]
    end
end

for prefix ∈ vcat(S, Σ)
    for suffix in E
        word = prefix * suffix
        if prefix == "ε" && suffix == "ε"
            word = "ε"
            table[prefix, suffix] = membership(word)
        else
            word = replace(word, "ε" => "")
            table[prefix, suffix] = membership(word)
        end
    end
end


while true
    unique_rows = Set()
    for p ∈ S
        row = collect(table[p, s] for s ∈ E)
        push!(unique_rows, row)
    end
    for p ∈ Σ
        row = collect(table[p, s] for s ∈ E)
        if !(row in unique_rows)
            push!(unique_rows, row)
            global Σ
            Σ = filter(x -> x != p, Σ)
            push!(S, p)
        else
            continue
        end
    end
    counter_example = equivalence(table)
    if counter_example == "true" 
        print_table()
        println("COMPLETED")
        exit
        break 
    end
    
    for suffix ∈ suffixes_of(counter_example)
        if suffix ∉ E
            push!(E, suffix)
            for prefix ∈ vcat(S, Σ)
                word = prefix * suffix
                word = replace(word, "ε" => "")
                table[prefix, suffix] = membership(word)
            end
        end
    end

    for prefix ∈ S
        for α ∈ collect(delete!(copy(ALPHABET), "ε"))
            new_prefix = prefix * α
            if new_prefix ∉ vcat(S, Σ)
                push!(Σ, new_prefix)
                for suffix ∈ E
                    word = new_prefix * suffix
                    word = replace(word, "ε" => "")
                    table[new_prefix, suffix] = membership(word)
                end
            end
        end
    end
end
