using JSON, HTTP

const ALPHABET = Set("$d" for d ∈ 0:9) ∪ ["ε"]

S = ["ε"]
E = ["ε"]
Σ = collect(delete!(copy(ALPHABET), "ε"))

table = Dict()

suffixes_of(ω) = [ω[i:lastindex(ω)] for i ∈ eachindex(ω)]

function prefixes_of(ω)
    prefixes = ["ε"]
    for i in 1:length(ω)
        push!(prefixes, ω[1:i])
    end
    return prefixes
end

payload = JSON.json(Dict("mode" => "easy"))
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

function InconsistencyTable(table)
    for prefix1 ∈ S, prefix2 ∈ S
        table_new_1 = join((table[prefix1, s] == true ? "1" : "0" for s ∈ E), " ")
        table_new_2 = join((table[prefix2, s] == true ? "1" : "0" for s ∈ E), " ")
        if table_new_1 == table_new_2
            for suffix ∈ E
                for letter in ALPHABET
                    word1 = prefix1 * letter * suffix
                    word2 = prefix1 * letter * suffix
                    word1 = replace(word1, "ε" => "")
                    word2 = replace(word2, "ε" => "")
                    suffix = replace(suffix, "ε" => "")
                    if membership(word1) != membership(word2)
                        push!(E, letter * suffix)
                        return true
                    end
                end
            end
        end
    end
    return false
end


function equivalence(table)
    main_prefixes = collect(S)
    #println("Here S", main_prefixes)
    non_main_prefixes = collect(Σ)
    #println("Here Σ", non_main_prefixes)
    suffixes = collect(E)
    #println("Here E", suffixes)
    #println(table)
    #println(main_prefixes, non_main_prefixes, suffixes)
    table_new = join((table[p, s] == true ? "1" : "0" for s ∈ suffixes, p ∈ vcat(main_prefixes, non_main_prefixes)), " ")
    #print_table()
    json_data = JSON.json(Dict(
        "main_prefixes" => join(main_prefixes, " "),
        "non_main_prefixes" => join(non_main_prefixes, " "),
        "suffixes" => join(suffixes, " "),
        "table" => table_new 
    ))
    #println(json_data)
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
    #@show unique_rows
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
    if !InconsistencyTable(table)
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

        for prefix ∈ prefixes_of(counter_example)
            if prefix ∉ vcat(S, Σ)
                push!(Σ, prefix)
                for suffix ∈ E
                    word = prefix * suffix
                    word = replace(word, "ε" => "")
                    table[prefix, suffix] = membership(word)
                end
            end
        end
    else
        for prefix ∈ vcat(S, Σ)
            suffix = E[end]
            word = prefix * suffix
            word = replace(word, "ε" => "")
            table[prefix, suffix] = membership(word)
        end
    end
end
