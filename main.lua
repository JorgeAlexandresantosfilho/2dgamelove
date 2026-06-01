local baralho, mao = {}, {}
local max_mao = 8

--esse bloco serve para guardar os estados do jogo
local estado_jogo = "menu" 
local estado_anterior = "jogando" 
local nivel_atual = 1
local pontuacao_atual = 0
local alvo_nivel = 200 

local maos_restantes = 4
local descartes_restantes = 3

local dinheiro = 4
local jokers_ativos = {}
local max_jokers = 5
local loja_itens = {}

local ultima_jogada_nome = ""
local ultimas_fichas, ultimo_mult, total_ganho = 0, 0, 0
local painel_w = 260 
local sfx_selecionar, musica_fundo

local anim_fichas, anim_mult, anim_pontuacao = 0, 0, 0
local scale_fichas, scale_mult, scale_pontuacao = 1, 1, 1
local bg_time, shake_time, shake_mag = 0, 0, 0
local transicao_alpha = 0
local transicao_estado_alvo = nil
local go_y = -200

local img_primo, img_par, img_impar, img_boss_2
local crt_shader, tela_canvas
local boss_dano_timer = 0
local tbl_primos = { [2]=true, [3]=true, [5]=true, [7]=true }

--essa função serve para mudar os estados do jogo
function mudarEstado(novo)
    if novo ~= estado_jogo then
        transicao_estado_alvo = novo
        transicao_alpha = 0
    end
end

--tremor na  na tela
function triggerShake(mag, duracao)
    shake_mag = mag
    shake_time = duracao
end

--fazendo transicao dos estdados para calcular game over e proximo blind
function updateTransitions(dt)
    if transicao_estado_alvo then
        transicao_alpha = transicao_alpha + dt * 3
        if transicao_alpha >= 1 then
            estado_jogo = transicao_estado_alvo
            transicao_estado_alvo = nil
            if estado_jogo == "game_over" then go_y = -200 end
        end
    elseif transicao_alpha > 0 then
        transicao_alpha = transicao_alpha - dt * 3
        if transicao_alpha < 0 then transicao_alpha = 0 end
    end
end

local cache_fontes = {}
function getFonte(tamanho)
    if not cache_fontes[tamanho] then
        cache_fontes[tamanho] = love.graphics.newFont(tamanho)
    end
    return cache_fontes[tamanho]
end

function lerp(a, b, t) return a + (b - a) * t end

--carregar sons e imagens
function love.load()
    love.window.setTitle("Algebratro")
    love.window.setMode(1280, 720, {resizable=false})
    love.graphics.setDefaultFilter("nearest", "nearest")
    
    tela_canvas = love.graphics.newCanvas(1280, 720)
    crt_shader = love.graphics.newShader[[
        extern number time;
        vec4 effect( vec4 color, Image texture, vec2 texture_coords, vec2 screen_coords )
        {
            vec2 uv = texture_coords;
            uv = uv * 2.0 - 1.0;
            vec2 offset = abs(uv.yx) / vec2(6.0, 4.0);
            uv = uv + uv * offset * offset;
            uv = uv * 0.5 + 0.5;

            if (uv.x < 0.0 || uv.x > 1.0 || uv.y < 0.0 || uv.y > 1.0) {
                return vec4(0.0, 0.0, 0.0, 1.0);
            }

            float r = Texel(texture, uv + vec2(0.003, 0.0)).r;
            float g = Texel(texture, uv).g;
            float b = Texel(texture, uv - vec2(0.003, 0.0)).b;

            float s = sin(screen_coords.y * 2.0 + time * 10.0) * 0.04;
            float v = 1.0 - smoothstep(0.4, 1.0, length(uv - 0.5));

            return vec4(r - s, g - s, b - s, 1.0) * color * v;
        }
    ]]
    
    pcall(function() img_primo = love.graphics.newImage("carta_primo.png") end)
    pcall(function() img_par = love.graphics.newImage("carta_par.png") end)
    pcall(function() img_impar = love.graphics.newImage("carta_impar.png") end)
    pcall(function() img_boss_2 = love.graphics.newImage("boss_2.png") end)

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
    mudarEstado("jogando")
end

function gerarLoja()
    loja_itens = {}
    local banco_de_jokers = {
        { nome = "Coringa Adição", desc = "+30 Fichas Finais", preco = 4, tipo = "fichas", valor = 30 },
        { nome = "Coringa Fator", desc = "+4 Mult Final", preco = 6, tipo = "mult", valor = 4 },
        { nome = "Mestre Primo", desc = "Primos: +8 Mult", preco = 8, tipo = "condicional", valor = 8 },
        { nome = "Matemático Nato", desc = "+80 Fichas Finais", preco = 6, tipo = "fichas", valor = 80 },
        { nome = "Teorema de Fermat", desc = "+15 Mult Final", preco = 10, tipo = "mult", valor = 15 },
        { nome = "Par Perfeito", desc = "Pares: +12 Mult", preco = 8, tipo = "condicional_par", valor = 12 },
        { nome = "O Ímpar", desc = "Ímpares: +12 Mult", preco = 8, tipo = "condicional_impar", valor = 12 },
        { nome = "Coringa Cósmico", desc = "+30 Mult Final", preco = 15, tipo = "mult", valor = 30 }
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
    bg_time = bg_time + dt
    if shake_time > 0 then shake_time = shake_time - dt end
    if boss_dano_timer > 0 then boss_dano_timer = boss_dano_timer - dt end
    updateTransitions(dt)

    anim_fichas = lerp(anim_fichas, ultimas_fichas, 10 * dt)
    anim_mult = lerp(anim_mult, ultimo_mult, 10 * dt)
    anim_pontuacao = lerp(anim_pontuacao, pontuacao_atual, 10 * dt)
    scale_fichas = lerp(scale_fichas, 1, 5 * dt)
    scale_mult = lerp(scale_mult, 1, 5 * dt)
    scale_pontuacao = lerp(scale_pontuacao, 1, 5 * dt)

    if estado_jogo == "game_over" then
        go_y = lerp(go_y, 230, 5 * dt)
    end

    if not transicao_estado_alvo and estado_jogo == "jogando" then
        local mx, my = love.mouse.getPosition()
        local inicio_x = painel_w + 100
        for i, carta in ipairs(mao) do
            local y_alvo = carta.selecionada and 460 or 500
            
            local cx = inicio_x + (i - 1) * 95
            if mx >= cx and mx <= (cx + 80) and my >= y_alvo and my <= (y_alvo + 120) then
                y_alvo = y_alvo - 20
            end

            carta.y_atual = lerp(carta.y_atual, y_alvo, 15 * dt)
        end

        if pontuacao_atual >= alvo_nivel then
            dinheiro = dinheiro + maos_restantes 
            if nivel_atual == 5 and not modo_infinito then
                mudarEstado("zerou_jogo")
            else
                mudarEstado("venceu_nivel")
            end
        elseif maos_restantes <= 0 and pontuacao_atual < alvo_nivel then
            mudarEstado("game_over")
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
            mudarEstado("pause")
            return
        end
        if x >= 20 and x <= 110 and y >= 450 and y <= 530 then
            estado_anterior = "jogando"
            mudarEstado("guia")
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
            if y >= 250 and y <= 300 then mudarEstado(estado_anterior) end
            if y >= 320 and y <= 370 then mudarEstado("guia") end
            if y >= 390 and y <= 440 then iniciarNivel(true) end
            if y >= 460 and y <= 510 then mudarEstado("menu") end
        end

    elseif estado_jogo == "guia" then
        local btn_x = 650
        if x >= btn_x and x <= btn_x + 240 and y >= 550 and y <= 600 then 
            mudarEstado(estado_anterior) 
        end

    elseif estado_jogo == "venceu_nivel" then
        local centro_x = 630
        if x >= centro_x and x <= centro_x + 280 and y >= 400 and y <= 460 then
            gerarLoja()
            mudarEstado("loja")
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
            local multiplicador = 1.8
            if nivel_atual % 5 == 0 then multiplicador = 2.5 end
            alvo_nivel = math.floor(alvo_nivel * multiplicador) 
            iniciarNivel(false)
        end

    elseif estado_jogo == "game_over" then
        local centro_x = 630
        if x >= centro_x and x <= centro_x + 280 and y >= 400 and y <= 460 then iniciarNivel(true) end
        
    elseif estado_jogo == "zerou_jogo" then
        local btn_w = 280
        local btn_h = 60
        local btn_inf_x = 340
        local btn_nov_x = 660
        local btn_y = 500
        
        if y >= btn_y and y <= btn_y + btn_h then
            if x >= btn_inf_x and x <= btn_inf_x + btn_w then
                modo_infinito = true
                nivel_atual = nivel_atual + 1
                local multiplicador = 1.8
                if nivel_atual % 5 == 0 then multiplicador = 2.5 end
                alvo_nivel = math.floor(alvo_nivel * multiplicador)
                iniciarNivel(false)
            elseif x >= btn_nov_x and x <= btn_nov_x + btn_w then
                iniciarNivel(true)
            end
        end
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

    for _, carta in ipairs(cartas_jogadas) do
        if carta.valor % 2 ~= 0 then todos_pares = false end
        if carta.valor % 2 == 0 then todos_impares = false end
        if not tbl_primos[carta.valor] then todos_primos = false end
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
        elseif joker.tipo == "condicional" and todos_primos and #cartas_jogadas >= 2 then mult = mult + joker.valor
        elseif joker.tipo == "condicional_par" and todos_pares and #cartas_jogadas >= 2 then mult = mult + joker.valor
        elseif joker.tipo == "condicional_impar" and todos_impares and #cartas_jogadas >= 2 then mult = mult + joker.valor
        end
    end

    ultimas_fichas = fichas_totais
    ultimo_mult = mult
    total_ganho = fichas_totais * mult
    pontuacao_atual = pontuacao_atual + total_ganho
    
    triggerShake(8, 0.3)
    boss_dano_timer = 0.5
    scale_fichas = 1.5
    scale_mult = 1.5
    scale_pontuacao = 1.3

    comprarCartas(#cartas_jogadas)
end

function desenharFundoDinamico()
    local r = 0.15 + (nivel_atual * 0.03) % 0.2
    local g = 0.35 - (nivel_atual * 0.02) % 0.15
    local b = 0.20 + (nivel_atual * 0.05) % 0.3
    
    if estado_jogo == "game_over" then
        r = 0.4 + 0.1 * math.sin(bg_time * 5)
        g, b = 0.05, 0.05
    end
    
    love.graphics.setBackgroundColor(r, g, b)
    
    love.graphics.setColor(1, 1, 1, 0.03)
    for i=1, 12 do
        local y = 360 + math.sin(bg_time * 1.5 + i) * 120
        love.graphics.circle("fill", i * 120, y, 180 + math.sin(bg_time * 2 + i) * 60)
    end
end

function love.draw()
    love.graphics.setCanvas(tela_canvas)
    love.graphics.clear()

    love.graphics.push()
    if shake_time > 0 then
        local sx = (math.random() * 2 - 1) * shake_mag
        local sy = (math.random() * 2 - 1) * shake_mag
        love.graphics.translate(sx, sy)
    end

    desenharFundoDinamico()
    
    if (estado_jogo == "jogando" or estado_jogo == "pause" or estado_jogo == "guia") and nivel_atual % 5 == 0 then
        local img_boss = img_boss_2
        if img_boss then
            love.graphics.push()
            local bx = 1280 / 2 + 130 
            local by = 720 / 2 - 50 + math.sin(bg_time * 2) * 20
            
            if boss_dano_timer > 0 then
                love.graphics.setColor(1, 0.3, 0.3)
                bx = bx + (math.random() * 2 - 1) * 10
                by = by + (math.random() * 2 - 1) * 10
            else
                love.graphics.setColor(1, 1, 1)
            end
            
            local iw, ih = img_boss:getDimensions()
            local scale = 350 / math.max(iw, ih)
            
            love.graphics.setBlendMode("add", "alphamultiply")
            love.graphics.draw(img_boss, bx, by, 0, scale, scale, iw/2, ih/2)
            love.graphics.setBlendMode("alpha")
            love.graphics.pop()
        end
    end
    
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
        
        love.graphics.pop()
        if transicao_alpha > 0 then
            love.graphics.setColor(0, 0, 0, transicao_alpha)
            love.graphics.rectangle("fill", 0, 0, 1280, 720)
        end
        
        love.graphics.setCanvas()
        love.graphics.setColor(1, 1, 1)
        love.graphics.setShader(crt_shader)
        if crt_shader:hasUniform("time") then crt_shader:send("time", bg_time) end
        love.graphics.draw(tela_canvas, 0, 0)
        love.graphics.setShader()
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
    love.graphics.push()
    love.graphics.translate(175, 135)
    love.graphics.scale(scale_pontuacao)
    love.graphics.printf(math.floor(anim_pontuacao), -65, -15, 130, "right")
    love.graphics.pop()

    love.graphics.push()
    love.graphics.translate(67.5, 197.5)
    love.graphics.scale(scale_fichas)
    love.graphics.setColor(0.1, 0.5, 0.9) 
    love.graphics.rectangle("fill", -57.5, -27.5, 115, 55, 8)
    love.graphics.setColor(1, 1, 1)
    love.graphics.setFont(getFonte(28))
    love.graphics.printf(math.floor(anim_fichas), -57.5, -15.5, 115, "center")
    love.graphics.pop()
    
    love.graphics.push()
    love.graphics.translate(192.5, 197.5)
    love.graphics.scale(scale_mult)
    love.graphics.setColor(0.9, 0.2, 0.2) 
    love.graphics.rectangle("fill", -57.5, -27.5, 115, 55, 8)
    love.graphics.setColor(1, 1, 1)
    love.graphics.printf(math.floor(anim_mult), -57.5, -15.5, 115, "center")
    love.graphics.pop()
    
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
        love.graphics.printf("Blind: " .. nivel_atual .. " | Meta: " .. alvo_nivel, painel_w, 20, 1280 - painel_w, "center")

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
            
            local img_alvo = img_impar
            if tbl_primos[carta.valor] then
                img_alvo = img_primo
            elseif carta.valor % 2 == 0 then
                img_alvo = img_par
            end
            
            if img_alvo then
                local iw, ih = img_alvo:getDimensions()
                local sx, sy = 80 / iw, 120 / ih
                love.graphics.draw(img_alvo, x, y, 0, sx, sy)
            else
                love.graphics.rectangle("fill", x, y, 80, 120, 8)
            end

            love.graphics.setColor(0, 0, 0)
            love.graphics.setFont(getFonte(36)) 
            love.graphics.printf(carta.valor, x + 2, y + 37, 80, "center") 
            love.graphics.setColor(1, 1, 1)
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
        love.graphics.printf("Voce foi derrotado", painel_w, go_y, 1280 - painel_w, "center")
        love.graphics.setColor(0.9, 0.6, 0.1)
        love.graphics.rectangle("fill", centro_x, 400, 280, 60, 10)
        love.graphics.setColor(0, 0, 0)
        love.graphics.setFont(getFonte(24))
        love.graphics.printf("REINICIAR", centro_x, 415, 280, "center")
        
    elseif estado_jogo == "zerou_jogo" then
        love.graphics.setColor(0, 0, 0, 0.85)
        love.graphics.rectangle("fill", painel_w, 0, 1280 - painel_w, 720)
        love.graphics.setColor(0.2, 0.8, 0.2)
        love.graphics.setFont(getFonte(60))
        love.graphics.printf("VOCÊ ZEROU!", painel_w, 230, 1280 - painel_w, "center")
        
        love.graphics.setColor(1, 1, 1)
        love.graphics.setFont(getFonte(24))
        love.graphics.printf("O Olho Cósmico foi derrotado.\nSeu domínio matemático é absoluto.", painel_w, 330, 1280 - painel_w, "center")
        
        local btn_w = 280
        local btn_inf_x = 340
        local btn_nov_x = 660
        
        love.graphics.setColor(0.7, 0.2, 0.9)
        love.graphics.rectangle("fill", btn_inf_x, 500, btn_w, 60, 10)
        love.graphics.setColor(1, 1, 1)
        love.graphics.printf("MODO INFINITO", btn_inf_x, 515, btn_w, "center")
        
        love.graphics.setColor(0.9, 0.6, 0.1)
        love.graphics.rectangle("fill", btn_nov_x, 500, btn_w, 60, 10)
        love.graphics.setColor(0, 0, 0)
        love.graphics.printf("NOVA TENTATIVA", btn_nov_x, 515, btn_w, "center")
    end

    love.graphics.pop()

    if transicao_alpha > 0 then
        love.graphics.setColor(0, 0, 0, transicao_alpha)
        love.graphics.rectangle("fill", 0, 0, 1280, 720)
    end

    love.graphics.setCanvas()
    love.graphics.setColor(1, 1, 1)
    love.graphics.setShader(crt_shader)
    if crt_shader:hasUniform("time") then crt_shader:send("time", bg_time) end
    love.graphics.draw(tela_canvas, 0, 0)
    love.graphics.setShader()
end