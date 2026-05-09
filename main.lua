-- main.lua

local baralho, mao = {}, {}
local max_mao = 8

-- MÁQUINA DE ESTADOS
local estado_jogo = "menu" 
local estado_anterior = "jogando" 
local nivel_atual = 1
local pontuacao_atual = 0
local alvo_nivel = 200 

-- LIMITES DA RODADA
local maos_restantes = 4
local descartes_restantes = 3

-- ECONOMIA E JOKERS
local dinheiro = 4
local jokers_ativos = {}
local max_jokers = 5
local loja_itens = {}

local ultima_jogada_nome = ""
local ultimas_fichas, ultimo_mult, total_ganho = 0, 0, 0
local painel_w = 260 
local sfx_selecionar, musica_fundo

-- ==========================================
-- SISTEMA DE CACHE E PRÉ-LOAD
-- ==========================================
local cache_fontes = {}
function getFonte(tamanho)
    if not cache_fontes[tamanho] then
        cache_fontes[tamanho] = love.graphics.newFont(tamanho)
    end
    return cache_fontes[tamanho]
end

function lerp(a, b, t) return a + (b - a) * t end

function love.load()
    love.window.setTitle("Algebratro")
    love.window.setMode(1280, 720, {resizable=false})
    math.randomseed(os.time())
    
    local tamanhos = {12, 14, 16, 18, 20, 22, 24, 28, 32, 36, 40, 48, 60, 80}
    for _, tam in ipairs(tamanhos) do getFonte(tam) end
    
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
        alvo_nivel = 200
        dinheiro = 4
        jokers_ativos = {}
    end
    
    pontuacao_atual = 0
    maos_restantes = 4
    descartes_restantes = 3
    ultima_jogada_nome = ""
    ultimas_fichas = 0
    ultimo_mult = 0
    baralho, mao = {}, {}
    
    criarBaralho()
    embaralhar()
    comprarCartas(max_mao)
    estado_jogo = "jogando"
end

function gerarLoja()
    loja_itens = {}
    local banco_de_jokers = {
        { nome = "Coringa Adição", desc = "+30 Fichas Finais", preco = 4, tipo = "fichas", valor = 30 },
        { nome = "Coringa Fator", desc = "+4 Mult Final", preco = 6, tipo = "mult", valor = 4 },
        { nome = "Mestre Primo", desc = "Primos: +8 Mult", preco = 8, tipo = "condicional", valor = 8 }
    }
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
        if #baralho > 0 and #mao < max_mao then 
            table.insert(mao, table.remove(baralho)) 
        end
    end
end

function love.update(dt)
    if estado_jogo == "jogando" then
        for _, carta in ipairs(mao) do
            local y_alvo = carta.selecionada and 460 or 500
            carta.y_atual = lerp(carta.y_atual, y_alvo, 15 * dt)
        end

        if pontuacao_atual >= alvo_nivel then
            dinheiro = dinheiro + maos_restantes 
            estado_jogo = "venceu_nivel"
        end
        
        if maos_restantes <= 0 and pontuacao_atual < alvo_nivel then
            estado_jogo = "game_over"
        end
    end
end

function love.mousepressed(x, y, button)
    if button ~= 1 then return end

    if estado_jogo == "menu" then
        local menu_btn_x = 500
        if x >= menu_btn_x and x <= menu_btn_x + 280 and y >= 350 and y <= 430 then
            if sfx_selecionar then sfx_selecionar:clone():play() end
            iniciarNivel(true)
        end
        
    elseif estado_jogo == "jogando" then
        if x >= 20 and x <= 110 and y >= 550 and y <= 630 then
            estado_anterior = "jogando"
            estado_jogo = "pause"
            return
        end
        if x >= 20 and x <= 110 and y >= 450 and y <= 530 then
            estado_anterior = "jogando"
            estado_jogo = "guia"
            return
        end

        if x >= 620 and x <= 760 and y >= 380 and y <= 425 and descartes_restantes > 0 then
            descartarCartas()
            return
        end

        if x >= 780 and x <= 920 and y >= 380 and y <= 425 and maos_restantes > 0 then
            avaliarEJogar()
            return
        end

        local selecionadas_count = 0
        for _, c in ipairs(mao) do if c.selecionada then selecionadas_count = selecionadas_count + 1 end end

        local inicio_x = painel_w + 100
        for i, carta in ipairs(mao) do
            local cx = inicio_x + (i - 1) * 95
            if x >= cx and x <= (cx + 80) and y >= carta.y_atual and y <= (carta.y_atual + 120) then
                if not carta.selecionada and selecionadas_count >= 5 then
                    -- Limite de 5 atingido
                else
                    carta.selecionada = not carta.selecionada
                    if sfx_selecionar then sfx_selecionar:clone():play() end
                end
                break
            end
        end
        
    elseif estado_jogo == "pause" then
        local btn_x = 650 
        if x >= btn_x and x <= btn_x + 240 then
            if y >= 250 and y <= 300 then estado_jogo = estado_anterior end
            if y >= 320 and y <= 370 then estado_jogo = "guia" end
            if y >= 390 and y <= 440 then iniciarNivel(true) end
            if y >= 460 and y <= 510 then estado_jogo = "menu" end
        end

    elseif estado_jogo == "guia" then
        local btn_x = 650
        if x >= btn_x and x <= btn_x + 240 and y >= 550 and y <= 600 then 
            estado_jogo = estado_anterior 
        end

    elseif estado_jogo == "venceu_nivel" then
        local centro_x = 630
        if x >= centro_x and x <= centro_x + 280 and y >= 400 and y <= 460 then
            gerarLoja()
            estado_jogo = "loja"
        end
        
    elseif estado_jogo == "loja" then
        local centro_x = 630
        local inicio_loja_x = 440
        for i, item in ipairs(loja_itens) do
            local ix = inicio_loja_x + (i - 1) * 220
            if x >= ix and x <= (ix + 180) and y >= 250 and y <= 450 then
                if dinheiro >= item.preco and #jokers_ativos < max_jokers then
                    dinheiro = dinheiro - item.preco
                    table.insert(jokers_ativos, item)
                    table.remove(loja_itens, i)
                    if sfx_selecionar then sfx_selecionar:clone():play() end
                end
                break
            end
        end
        if x >= centro_x and x <= centro_x + 280 and y >= 550 and y <= 610 then
            nivel_atual = nivel_atual + 1
            alvo_nivel = math.floor(alvo_nivel * 1.8) 
            iniciarNivel(false)
        end

    elseif estado_jogo == "game_over" then
        local centro_x = 630
        if x >= centro_x and x <= centro_x + 280 and y >= 400 and y <= 460 then iniciarNivel(true) end
    end
end

function descartarCartas()
    local selecionadas = 0
    for i = #mao, 1, -1 do
        if mao[i].selecionada then
            selecionadas = selecionadas + 1
            table.remove(mao, i)
        end
    end
    if selecionadas > 0 then
        descartes_restantes = descartes_restantes - 1
        comprarCartas(selecionadas)
    end
end

function avaliarEJogar()
    local cartas_jogadas = {}
    local fichas_soma_cartas = 0
    
    for i = #mao, 1, -1 do
        if mao[i].selecionada then
            fichas_soma_cartas = fichas_soma_cartas + mao[i].valor
            table.insert(cartas_jogadas, mao[i])
            table.remove(mao, i)
        end
    end

    if #cartas_jogadas == 0 then return end
    maos_restantes = maos_restantes - 1

    local mult = 1
    local fichas_base_mao = 10 
    ultima_jogada_nome = "Carta Alta"
    
    local todos_pares, todos_impares, todos_primos = true, true, true
    local primos = { [2]=true, [3]=true, [5]=true, [7]=true }

    for _, carta in ipairs(cartas_jogadas) do
        if carta.valor % 2 ~= 0 then todos_pares = false end
        if carta.valor % 2 == 0 then todos_impares = false end
        if not primos[carta.valor] then todos_primos = false end
    end

    if todos_primos and #cartas_jogadas >= 2 then
        ultima_jogada_nome = "Conjunto Primo"
        fichas_base_mao = 40
        mult = 5
    elseif todos_pares and #cartas_jogadas >= 2 then
        ultima_jogada_nome = "Conjunto Par"
        fichas_base_mao = 20
        mult = 3
    elseif todos_impares and #cartas_jogadas >= 2 then
        ultima_jogada_nome = "Conjunto Ímpar"
        fichas_base_mao = 20
        mult = 3
    end

    local fichas_totais = fichas_base_mao + fichas_soma_cartas

    for _, joker in ipairs(jokers_ativos) do
        if joker.tipo == "fichas" then fichas_totais = fichas_totais + joker.valor
        elseif joker.tipo == "mult" then mult = mult + joker.valor
        elseif joker.tipo == "condicional" and todos_primos and #cartas_jogadas >= 2 then mult = mult + joker.valor end
    end

    ultimas_fichas = fichas_totais
    ultimo_mult = mult
    total_ganho = fichas_totais * mult
    pontuacao_atual = pontuacao_atual + total_ganho

    comprarCartas(#cartas_jogadas)
end

function love.draw()
    love.graphics.setBackgroundColor(0.15, 0.35, 0.20)
    
    if estado_jogo == "menu" then
        local menu_btn_x = 500 
        love.graphics.setColor(1, 1, 1)
        love.graphics.setFont(getFonte(80))
        love.graphics.printf("ALGEBRATRO", 0, 150, 1280, "center")
        love.graphics.setColor(0.9, 0.6, 0.1)
        love.graphics.rectangle("fill", menu_btn_x, 350, 280, 80, 15)
        love.graphics.setColor(0, 0, 0)
        love.graphics.setFont(getFonte(32))
        love.graphics.printf("INICIAR", menu_btn_x, 370, 280, "center")
        return
    end

    local centro_x = 630 

    love.graphics.setColor(0.18, 0.18, 0.18) 
    love.graphics.rectangle("fill", 0, 0, painel_w, 720)
    
    love.graphics.setColor(1, 1, 1)
    love.graphics.setFont(getFonte(22))
    love.graphics.printf("Escolha seu\npróximo Blind", 0, 30, painel_w, "center")
    
    love.graphics.setColor(0.1, 0.1, 0.1)
    love.graphics.rectangle("fill", 10, 110, 240, 45, 8)
    love.graphics.setColor(1, 1, 1)
    love.graphics.setFont(getFonte(12))
    love.graphics.print("da Rodada\nPontuação", 20, 118)
    love.graphics.setFont(getFonte(24))
    love.graphics.printf(math.floor(pontuacao_atual), 110, 120, 130, "right")

    love.graphics.setColor(0.1, 0.5, 0.9) 
    love.graphics.rectangle("fill", 10, 170, 115, 55, 8)
    love.graphics.setColor(1, 1, 1)
    love.graphics.setFont(getFonte(28))
    love.graphics.printf(ultimas_fichas, 10, 182, 115, "center")
    
    love.graphics.setColor(0.9, 0.2, 0.2) 
    love.graphics.rectangle("fill", 135, 170, 115, 55, 8)
    love.graphics.setColor(1, 1, 1)
    love.graphics.printf(ultimo_mult, 135, 182, 115, "center")
    
    love.graphics.setColor(0.2, 0.2, 0.2)
    love.graphics.rectangle("fill", 115, 180, 30, 35, 5)
    love.graphics.setColor(1, 1, 1)
    love.graphics.setFont(getFonte(20))
    love.graphics.print("X", 123, 187)

    love.graphics.setColor(0.8, 0.2, 0.2)
    love.graphics.rectangle("fill", 20, 450, 90, 80, 8)
    love.graphics.setColor(1, 1, 1)
    love.graphics.setFont(getFonte(14))
    love.graphics.printf("da Tentativa\nInformação", 20, 475, 90, "center")

    love.graphics.setColor(0.9, 0.6, 0.1)
    love.graphics.rectangle("fill", 20, 550, 90, 80, 8)
    love.graphics.setColor(0, 0, 0)
    love.graphics.setFont(getFonte(16))
    love.graphics.printf("Opções", 20, 580, 90, "center")

    love.graphics.setColor(0.1, 0.1, 0.1)
    love.graphics.rectangle("fill", 125, 450, 55, 60, 5)
    love.graphics.rectangle("fill", 185, 450, 55, 60, 5)
    love.graphics.setColor(1, 1, 1)
    love.graphics.setFont(getFonte(12))
    love.graphics.print("Mãos", 135, 455)
    love.graphics.print("Descartes", 187, 455)
    love.graphics.setFont(getFonte(28))
    love.graphics.setColor(0.2, 0.6, 1) 
    love.graphics.printf(maos_restantes, 125, 475, 55, "center")
    love.graphics.setColor(1, 0.3, 0.3) 
    love.graphics.printf(descartes_restantes, 185, 475, 55, "center")

    love.graphics.setColor(0.1, 0.1, 0.1)
    love.graphics.rectangle("fill", 125, 520, 115, 45, 5)
    love.graphics.setColor(0.9, 0.7, 0.1)
    love.graphics.setFont(getFonte(24))
    love.graphics.printf("$" .. dinheiro, 125, 530, 115, "center")

    if estado_jogo == "jogando" or estado_jogo == "pause" or estado_jogo == "guia" then
        
        -- AJUSTE VISUAL DO JOKER APLICADO AQUI
        local jx_inicio = painel_w + 20
        for i, joker in ipairs(jokers_ativos) do
            local jx = jx_inicio + (i - 1) * 130
            love.graphics.setColor(0.3, 0.3, 0.3)
            love.graphics.rectangle("fill", jx, 15, 120, 90, 5)
            love.graphics.setColor(1, 1, 1)
            love.graphics.setFont(getFonte(14))
            love.graphics.printf(joker.nome, jx, 20, 120, "center")
            love.graphics.setColor(0.9, 0.7, 0.1)
            love.graphics.setFont(getFonte(12))
            love.graphics.printf(joker.desc, jx, 55, 120, "center")
        end

        love.graphics.setColor(1, 1, 1)
        love.graphics.setFont(getFonte(20))
        love.graphics.printf("Meta do Blind: " .. alvo_nivel, painel_w, 20, 1280 - painel_w, "center")

        love.graphics.setFont(getFonte(18))
        love.graphics.setColor(0.8, 0.2, 0.2) 
        love.graphics.rectangle("fill", 620, 380, 140, 45, 8)
        love.graphics.setColor(1, 1, 1)
        love.graphics.printf("DESCARTAR", 620, 393, 140, "center")

        love.graphics.setColor(0.9, 0.6, 0.1) 
        love.graphics.rectangle("fill", 780, 380, 140, 45, 8)
        love.graphics.setColor(0, 0, 0)
        love.graphics.printf("JOGAR", 780, 393, 140, "center")

        local inicio_x = painel_w + 100
        for i, carta in ipairs(mao) do
            local x = inicio_x + (i - 1) * 95
            local y = carta.y_atual
            
            love.graphics.setColor(0, 0, 0, 0.4)
            love.graphics.rectangle("fill", x + 6, y + 6, 80, 120, 8)
            love.graphics.setColor(1, 1, 1) 
            love.graphics.rectangle("fill", x, y, 80, 120, 8)
            love.graphics.setColor(0.3, 0.3, 0.3)
            love.graphics.setLineWidth(2)
            love.graphics.rectangle("line", x, y, 80, 120, 8)
            love.graphics.setColor(0.8, 0.8, 0.8)
            love.graphics.setLineWidth(1)
            love.graphics.rectangle("line", x + 4, y + 4, 72, 112, 4)
            love.graphics.setColor(0.1, 0.1, 0.1)
            love.graphics.setFont(getFonte(36)) 
            love.graphics.printf(carta.valor, x, y + 35, 80, "center")
        end

        love.graphics.setColor(0.8, 0.2, 0.2)
        love.graphics.rectangle("fill", 1120, 520, 80, 120, 8)
        love.graphics.setColor(1, 1, 1)
        love.graphics.setLineWidth(2)
        love.graphics.rectangle("line", 1124, 524, 72, 112, 4)
        love.graphics.setFont(getFonte(14))
        love.graphics.printf(#baralho .. "/40", 1120, 650, 80, "center")
    end

    if estado_jogo == "pause" or estado_jogo == "guia" then
        love.graphics.setColor(0, 0, 0, 0.8)
        love.graphics.rectangle("fill", painel_w, 0, 1280 - painel_w, 720)
        
        if estado_jogo == "pause" then
            love.graphics.setColor(1, 1, 1)
            love.graphics.setFont(getFonte(48))
            love.graphics.printf("OPÇÕES", painel_w, 150, 1280 - painel_w, "center")
            
            local btn_w, btn_h = 240, 50
            local btn_x = 650
            
            love.graphics.setColor(0.2, 0.6, 1); love.graphics.rectangle("fill", btn_x, 250, btn_w, btn_h, 8)
            love.graphics.setColor(0.8, 0.2, 0.2); love.graphics.rectangle("fill", btn_x, 320, btn_w, btn_h, 8)
            love.graphics.setColor(0.9, 0.6, 0.1); love.graphics.rectangle("fill", btn_x, 390, btn_w, btn_h, 8)
            love.graphics.setColor(0.4, 0.4, 0.4); love.graphics.rectangle("fill", btn_x, 460, btn_w, btn_h, 8)
            
            love.graphics.setColor(1, 1, 1)
            love.graphics.setFont(getFonte(20))
            love.graphics.printf("Continuar", btn_x, 263, btn_w, "center")
            love.graphics.printf("Guia de Mãos", btn_x, 333, btn_w, "center")
            love.graphics.printf("Nova Tentativa", btn_x, 403, btn_w, "center")
            love.graphics.printf("Menu Principal", btn_x, 473, btn_w, "center")
            
        elseif estado_jogo == "guia" then
            love.graphics.setColor(1, 1, 1)
            love.graphics.setFont(getFonte(40))
            love.graphics.printf("GUIA DE JOGADAS", painel_w, 100, 1280 - painel_w, "center")
            love.graphics.setFont(getFonte(24))
            love.graphics.printf("Carta(s) Alta(s): Base 10 Fichas x1 Mult\n\nConjunto Par: Base 20 Fichas x3 Mult\n\nConjunto Ímpar: Base 20 Fichas x3 Mult\n\nConjunto Primo: Base 40 Fichas x5 Mult", painel_w, 200, 1280 - painel_w, "center")
            
            local btn_x = 650
            love.graphics.setColor(0.8, 0.2, 0.2)
            love.graphics.rectangle("fill", btn_x, 550, 240, 50, 8)
            love.graphics.setColor(1, 1, 1)
            love.graphics.printf("FECHAR", btn_x, 563, 240, "center")
        end
    end

    if estado_jogo == "venceu_nivel" then
        love.graphics.setColor(0, 0, 0, 0.8)
        love.graphics.rectangle("fill", painel_w, 0, 1280 - painel_w, 720)
        love.graphics.setColor(0.2, 0.8, 0.2)
        love.graphics.setFont(getFonte(48))
        love.graphics.printf("BLIND SUPERADO!", painel_w, 250, 1280 - painel_w, "center")
        love.graphics.setColor(0.9, 0.6, 0.1)
        love.graphics.rectangle("fill", centro_x, 400, 280, 60, 10)
        love.graphics.setColor(0, 0, 0)
        love.graphics.setFont(getFonte(24))
        love.graphics.printf("IR PARA A LOJA", centro_x, 415, 280, "center")
        
    elseif estado_jogo == "loja" then
        love.graphics.setColor(0.1, 0.1, 0.1, 0.9)
        love.graphics.rectangle("fill", painel_w, 0, 1280 - painel_w, 720)
        love.graphics.setColor(1, 1, 1)
        love.graphics.setFont(getFonte(48))
        love.graphics.printf("A LOJA", painel_w, 100, 1280 - painel_w, "center")
        
        local inicio_loja_x = painel_w + 200
        for i, item in ipairs(loja_itens) do
            local ix = inicio_loja_x + (i - 1) * 220
            love.graphics.setColor(0.3, 0.3, 0.3)
            love.graphics.rectangle("fill", ix, 250, 180, 200, 10)
            love.graphics.setColor(1, 1, 1)
            love.graphics.setFont(getFonte(20))
            love.graphics.printf(item.nome, ix + 10, 270, 160, "center")
            love.graphics.setFont(getFonte(16))
            love.graphics.setColor(0.8, 0.8, 0.8)
            love.graphics.printf(item.desc, ix + 10, 320, 160, "center")
            if dinheiro >= item.preco then love.graphics.setColor(0.2, 0.8, 0.2) else love.graphics.setColor(0.8, 0.2, 0.2) end
            love.graphics.printf("$ " .. item.preco, ix, 400, 180, "center")
        end
        love.graphics.setColor(0.9, 0.6, 0.1)
        love.graphics.rectangle("fill", centro_x, 550, 280, 60, 10)
        love.graphics.setColor(0, 0, 0)
        love.graphics.setFont(getFonte(24))
        love.graphics.printf("PRÓXIMO BLIND", centro_x, 565, 280, "center")

    elseif estado_jogo == "game_over" then
        love.graphics.setColor(0, 0, 0, 0.85)
        love.graphics.rectangle("fill", painel_w, 0, 1280 - painel_w, 720)
        love.graphics.setColor(0.9, 0.2, 0.2)
        love.graphics.setFont(getFonte(60))
        love.graphics.printf("GAME OVER", painel_w, 230, 1280 - painel_w, "center")
        love.graphics.setColor(0.9, 0.6, 0.1)
        love.graphics.rectangle("fill", centro_x, 400, 280, 60, 10)
        love.graphics.setColor(0, 0, 0)
        love.graphics.setFont(getFonte(24))
        love.graphics.printf("REINICIAR", centro_x, 415, 280, "center")
    end
end