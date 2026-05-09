-- main.lua

local baralho, mao = {}, {}
local max_mao = 8

-- MÁQUINA DE ESTADOS
local estado_jogo = "menu" -- "menu", "jogando", "venceu_nivel", "loja", "game_over"
local nivel_atual = 1
local pontuacao_atual = 0
local alvo_nivel = 500

-- NOVIDADE: ECONOMIA E JOKERS
local dinheiro = 0
local jokers_ativos = {} -- Os jokers que você comprou (máximo 3 para simplificar)
local max_jokers = 3
local loja_itens = {} -- Jokers disponíveis na loja atual

local ultima_jogada_nome = ""
local ultimas_fichas, ultimo_mult, total_ganho = 0, 0, 0
local painel_w = 320
local sfx_selecionar, musica_fundo

function lerp(a, b, t) return a + (b - a) * t end

function love.load()
    love.window.setTitle("Algebratro")
    love.window.setMode(1280, 720, {resizable=false})
    math.randomseed(os.time())
    
    pcall(function() 
        musica_fundo = love.audio.newSource("fundo.mp3", "stream")
        musica_fundo:setLooping(true)
        musica_fundo:setVolume(0.3)
        musica_fundo:play()
    end)
    pcall(function() sfx_selecionar = love.audio.newSource("click.wav", "static") end)
end

function iniciarNivel(resetar_tudo)
    if resetar_tudo then
        nivel_atual = 1
        alvo_nivel = 500
        dinheiro = 0
        jokers_ativos = {}
    end
    
    pontuacao_atual = 0
    ultima_jogada_nome = ""
    baralho, mao = {}, {}
    
    criarBaralho()
    embaralhar()
    comprarCartas(max_mao)
    estado_jogo = "jogando"
end

-- NOVIDADE: Geração da Loja
function gerarLoja()
    loja_itens = {}
    -- Vamos criar um "banco de dados" simples de Jokers
    local banco_de_jokers = {
        { nome = "Coringa da Adição", desc = "+20 Fichas por jogada", preco = 4, tipo = "fichas", valor = 20 },
        { nome = "Coringa Fator", desc = "+3 de Multiplicador", preco = 6, tipo = "mult", valor = 3 },
        { nome = "Mestre Primo", desc = "Primos dão +5 Mult extra", preco = 8, tipo = "condicional_primo", valor = 5 }
    }
    
    -- Sorteia 2 Jokers aleatórios para a loja
    table.insert(loja_itens, banco_de_jokers[math.random(1, #banco_de_jokers)])
    table.insert(loja_itens, banco_de_jokers[math.random(1, #banco_de_jokers)])
end

function criarBaralho()
    for copia = 1, 4 do
        for valor = 1, 10 do
            table.insert(baralho, { valor = valor, selecionada = false, y_atual = 500 })
        end
    end
end

function embaralhar()
    for i = #baralho, 2, -1 do
        local j = math.random(i)
        baralho[i], baralho[j] = baralho[j], baralho[i]
    end
end

function comprarCartas(quantidade)
    for i = 1, quantidade do
        if #baralho > 0 then table.insert(mao, table.remove(baralho)) end
    end
end

function love.update(dt)
    if estado_jogo == "jogando" then
        for _, carta in ipairs(mao) do
            local y_alvo = carta.selecionada and 470 or 500
            carta.y_atual = lerp(carta.y_atual, y_alvo, 15 * dt)
        end

        if pontuacao_atual >= alvo_nivel then
            dinheiro = dinheiro + 5 -- Recompensa fixa por bater a meta!
            estado_jogo = "venceu_nivel"
        end
        
        if #mao == 0 and #baralho == 0 and pontuacao_atual < alvo_nivel then
            estado_jogo = "game_over"
        end
    end
end

function love.mousepressed(x, y, button)
    if button ~= 1 then return end
    
    if estado_jogo == "menu" then
        if x >= 540 and x <= 790 and y >= 350 and y <= 430 then
            if sfx_selecionar then sfx_selecionar:clone():play() end
            iniciarNivel(true)
        end
        
    elseif estado_jogo == "jogando" then
        if x >= 600 and x <= 760 and y >= 350 and y <= 410 then
            avaliarEJogar()
            return
        end

        local inicio_x = painel_w + 50
        for i, carta in ipairs(mao) do
            local cx = inicio_x + (i - 1) * 95
            if x >= cx and x <= (cx + 80) and y >= carta.y_atual and y <= (carta.y_atual + 120) then
                carta.selecionada = not carta.selecionada
                if sfx_selecionar then sfx_selecionar:clone():play() end
                break
            end
        end
        
    elseif estado_jogo == "venceu_nivel" then
        if x >= 540 and x <= 790 and y >= 400 and y <= 460 then
            gerarLoja()
            estado_jogo = "loja" -- Manda pra loja em vez do próximo nível
        end
        
    elseif estado_jogo == "loja" then
        -- Lógica de clicar nos itens da loja para comprar
        local inicio_loja_x = 440
        for i, item in ipairs(loja_itens) do
            local ix = inicio_loja_x + (i - 1) * 220
            -- Hitbox do card do Joker na loja
            if x >= ix and x <= (ix + 180) and y >= 250 and y <= 450 then
                if dinheiro >= item.preco and #jokers_ativos < max_jokers then
                    dinheiro = dinheiro - item.preco
                    table.insert(jokers_ativos, item)
                    table.remove(loja_itens, i) -- Tira da loja
                    if sfx_selecionar then sfx_selecionar:clone():play() end
                end
                break
            end
        end
        
        -- Botão "Sair da Loja e Próximo Blind"
        if x >= 540 and x <= 790 and y >= 550 and y <= 610 then
            nivel_atual = nivel_atual + 1
            alvo_nivel = alvo_nivel * 2.5
            iniciarNivel(false)
        end

    elseif estado_jogo == "game_over" then
        if x >= 540 and x <= 790 and y >= 400 and y <= 460 then
            iniciarNivel(true)
        end
    end
end

function avaliarEJogar()
    local cartas_jogadas = {}
    local fichas = 0
    
    for i = #mao, 1, -1 do
        if mao[i].selecionada then
            fichas = fichas + mao[i].valor
            table.insert(cartas_jogadas, mao[i])
            table.remove(mao, i)
        end
    end

    if #cartas_jogadas == 0 then return end

    local mult = 1
    ultima_jogada_nome = "Carta(s) Alta(s)"
    local todos_pares, todos_impares, todos_primos = true, true, true
    local primos = { [2]=true, [3]=true, [5]=true, [7]=true }

    for _, carta in ipairs(cartas_jogadas) do
        if carta.valor % 2 ~= 0 then todos_pares = false end
        if carta.valor % 2 == 0 then todos_impares = false end
        if not primos[carta.valor] then todos_primos = false end
    end

    if todos_primos and #cartas_jogadas >= 2 then
        ultima_jogada_nome = "Conjunto Primo"
        mult = 5
    elseif todos_pares and #cartas_jogadas >= 2 then
        ultima_jogada_nome = "Conjunto Par"
        mult = 2
    elseif todos_impares and #cartas_jogadas >= 2 then
        ultima_jogada_nome = "Conjunto Ímpar"
        mult = 2
    end

    -- NOVIDADE: APLICANDO O EFEITO DOS JOKERS
    for _, joker in ipairs(jokers_ativos) do
        if joker.tipo == "fichas" then
            fichas = fichas + joker.valor
        elseif joker.tipo == "mult" then
            mult = mult + joker.valor
        elseif joker.tipo == "condicional_primo" and todos_primos and #cartas_jogadas >= 2 then
            mult = mult + joker.valor
        end
    end

    ultimas_fichas = fichas
    ultimo_mult = mult
    total_ganho = fichas * mult
    pontuacao_atual = pontuacao_atual + total_ganho

    comprarCartas(#cartas_jogadas)
end

function love.draw()
    love.graphics.setBackgroundColor(0.2, 0.45, 0.25)
    
    if estado_jogo == "menu" then
        love.graphics.setColor(1, 1, 1)
        love.graphics.setNewFont(80)
        love.graphics.printf("ALGEBRATRO", 0, 150, 1280, "center")
        
        love.graphics.setColor(0.9, 0.6, 0.1)
        love.graphics.rectangle("fill", 540, 350, 250, 80, 15)
        love.graphics.setColor(0, 0, 0)
        love.graphics.setNewFont(32)
        love.graphics.print("INICIAR", 605, 370)
        return
    end

    -- PAINEL LATERAL ESQUERDO
    love.graphics.setColor(0.15, 0.15, 0.15)
    love.graphics.rectangle("fill", 0, 0, painel_w, 720)
    
    love.graphics.setColor(1, 1, 1)
    love.graphics.setNewFont(28)
    love.graphics.print("Blind " .. nivel_atual, 20, 30)
    
    love.graphics.setColor(0.2, 0.2, 0.2)
    love.graphics.rectangle("fill", 20, 80, 280, 100, 10)
    love.graphics.setColor(1, 1, 1)
    love.graphics.setNewFont(18)
    love.graphics.print("Pontuação", 30, 90)
    love.graphics.setNewFont(40)
    love.graphics.print(math.floor(pontuacao_atual), 30, 120)

    love.graphics.setColor(0.2, 0.2, 0.2)
    love.graphics.rectangle("fill", 20, 200, 280, 100, 10)
    love.graphics.setColor(1, 1, 1)
    love.graphics.setNewFont(18)
    love.graphics.print("Alvo do Blind", 30, 210)
    love.graphics.setNewFont(40)
    love.graphics.setColor(0.9, 0.2, 0.2)
    love.graphics.print(math.floor(alvo_nivel), 30, 240)

    -- Mostrador de Dinheiro
    love.graphics.setColor(0.9, 0.7, 0.1)
    love.graphics.setNewFont(24)
    love.graphics.print("$" .. dinheiro, 20, 330)

    love.graphics.setColor(1, 1, 1)
    love.graphics.setNewFont(20)
    love.graphics.print("Cartas: " .. #baralho, 20, 650)

    -- ÁREA CENTRAL (JOGO)
    if estado_jogo == "jogando" then
        
        -- Desenhar os Jokers Ativos no topo da mesa
        local jx_inicio = painel_w + 20
        for i, joker in ipairs(jokers_ativos) do
            local jx = jx_inicio + (i - 1) * 110
            love.graphics.setColor(0.3, 0.3, 0.3)
            love.graphics.rectangle("fill", jx, 20, 100, 80, 5)
            love.graphics.setColor(1, 1, 1)
            love.graphics.setNewFont(14)
            love.graphics.printf(joker.nome, jx, 30, 100, "center")
            love.graphics.setColor(0.9, 0.7, 0.1)
            love.graphics.printf(joker.desc, jx, 50, 100, "center")
        end

        if ultima_jogada_nome ~= "" then
            love.graphics.setColor(1, 1, 1)
            love.graphics.setNewFont(24)
            love.graphics.printf(ultima_jogada_nome, painel_w, 150, 1280 - painel_w, "center")
            
            love.graphics.setColor(0.1, 0.5, 0.9)
            love.graphics.rectangle("fill", 520, 200, 100, 60, 8)
            love.graphics.setColor(1, 1, 1)
            love.graphics.printf(ultimas_fichas, 520, 215, 100, "center")
            love.graphics.printf("X", 620, 215, 60, "center")
            
            love.graphics.setColor(0.9, 0.2, 0.2)
            love.graphics.rectangle("fill", 680, 200, 100, 60, 8)
            love.graphics.setColor(1, 1, 1)
            love.graphics.printf(ultimo_mult, 680, 215, 100, "center")
            
            love.graphics.setColor(1, 1, 0.2)
            love.graphics.printf("+ " .. total_ganho, painel_w, 280, 1280 - painel_w, "center")
        end

        love.graphics.setColor(0.9, 0.6, 0.1)
        love.graphics.rectangle("fill", 600, 350, 160, 60, 8)
        love.graphics.setColor(0, 0, 0)
        love.graphics.setNewFont(24)
        love.graphics.print("JOGAR", 640, 365)

        local inicio_x = painel_w + 50
        for i, carta in ipairs(mao) do
            local x = inicio_x + (i - 1) * 95
            local y = carta.y_atual
            
            love.graphics.setColor(1, 1, 1) 
            love.graphics.rectangle("fill", x, y, 80, 120, 8, 8)
            love.graphics.setColor(0, 0, 0)
            love.graphics.setLineWidth(2)
            love.graphics.rectangle("line", x, y, 80, 120, 8, 8)
            
            love.graphics.setNewFont(36) 
            love.graphics.print(carta.valor, x + ((carta.valor >= 10) and 20 or 30), y + 40)
        end

    -- TELA DE LOJA
    elseif estado_jogo == "loja" then
        love.graphics.setColor(0.1, 0.1, 0.1, 0.9)
        love.graphics.rectangle("fill", painel_w, 0, 1280 - painel_w, 720)
        
        love.graphics.setColor(1, 1, 1)
        love.graphics.setNewFont(48)
        love.graphics.printf("A LOJA", painel_w, 100, 1280 - painel_w, "center")
        
        -- Desenha as opções da Loja
        local inicio_loja_x = 440
        for i, item in ipairs(loja_itens) do
            local ix = inicio_loja_x + (i - 1) * 220
            love.graphics.setColor(0.3, 0.3, 0.3)
            love.graphics.rectangle("fill", ix, 250, 180, 200, 10)
            
            love.graphics.setColor(1, 1, 1)
            love.graphics.setNewFont(20)
            love.graphics.printf(item.nome, ix + 10, 270, 160, "center")
            love.graphics.setNewFont(16)
            love.graphics.setColor(0.8, 0.8, 0.8)
            love.graphics.printf(item.desc, ix + 10, 320, 160, "center")
            
            -- Se tiver dinheiro, botão verde, senão vermelho
            if dinheiro >= item.preco then love.graphics.setColor(0.2, 0.8, 0.2) else love.graphics.setColor(0.8, 0.2, 0.2) end
            love.graphics.printf("$ " .. item.preco, ix, 400, 180, "center")
        end
        
        -- Botão Pular Loja
        love.graphics.setColor(0.9, 0.6, 0.1)
        love.graphics.rectangle("fill", 540, 550, 250, 60, 10)
        love.graphics.setColor(0, 0, 0)
        love.graphics.setNewFont(24)
        love.graphics.print("PRÓXIMO BLIND", 570, 565)

    -- TELAS DE INTERRUPÇÃO
    elseif estado_jogo == "venceu_nivel" then
        love.graphics.setColor(0, 0, 0, 0.8)
        love.graphics.rectangle("fill", painel_w, 0, 1280 - painel_w, 720)
        
        love.graphics.setColor(0.2, 0.8, 0.2)
        love.graphics.setNewFont(48)
        love.graphics.printf("BLIND SUPERADO!", painel_w, 250, 1280 - painel_w, "center")
        
        love.graphics.setColor(0.9, 0.6, 0.1)
        love.graphics.rectangle("fill", 540, 400, 250, 60, 10)
        love.graphics.setColor(0, 0, 0)
        love.graphics.setNewFont(24)
        love.graphics.print("IR PARA A LOJA", 575, 415)
        
    elseif estado_jogo == "game_over" then
        love.graphics.setColor(0, 0, 0, 0.85)
        love.graphics.rectangle("fill", painel_w, 0, 1280 - painel_w, 720)
        love.graphics.setColor(0.9, 0.2, 0.2)
        love.graphics.setNewFont(60)
        love.graphics.printf("GAME OVER", painel_w, 230, 1280 - painel_w, "center")
        love.graphics.setColor(0.9, 0.6, 0.1)
        love.graphics.rectangle("fill", 540, 400, 250, 60, 10)
        love.graphics.setColor(0, 0, 0)
        love.graphics.setNewFont(24)
        love.graphics.print("REINICIAR", 605, 415)
    end
end