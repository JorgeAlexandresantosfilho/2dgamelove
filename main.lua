-- main.lua

local baralho = {}
local mao = {}
local max_mao = 8


local estado_jogo = "jogando" 
local nivel_atual = 1
local pontuacao_atual = 0
local alvo_nivel = 500


local ultima_jogada_nome = ""
local ultimas_fichas = 0
local ultimo_mult = 0
local total_ganho = 0


local painel_w = 320 

function love.load()
    love.window.setMode(1280, 720, {resizable=false})
    math.randomseed(os.time())
    
    iniciarNivel()
end

function iniciarNivel()
    baralho = {}
    mao = {}
    criarBaralho()
    embaralhar()
    comprarCartas(max_mao)
    estado_jogo = "jogando"
end

function criarBaralho()
    for copia = 1, 4 do
        for valor = 1, 10 do
            table.insert(baralho, { valor = valor, selecionada = false })
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
        if #baralho > 0 then
            table.insert(mao, table.remove(baralho))
        end
    end
end

function love.update(dt)
    --verificacao de meta para o proximo nivel
    if estado_jogo == "jogando" and pontuacao_atual >= alvo_nivel then
        estado_jogo = "venceu_nivel"
    end
end

function love.mousepressed(x, y, button)
    if button == 1 then
        if estado_jogo == "jogando" then
            
            local btn_x, btn_y, btn_w, btn_h = 600, 350, 160, 60
            if x >= btn_x and x <= (btn_x + btn_w) and y >= btn_y and y <= (btn_y + btn_h) then
                avaliarEJogar()
                return
            end

            -- Clicar nas cartas
            local inicio_x = painel_w + 50
            for i, carta in ipairs(mao) do
                local cx = inicio_x + (i - 1) * 95
                local cy = 500
                if carta.selecionada then cy = cy - 20 end
                
                if x >= cx and x <= (cx + 80) and y >= cy and y <= (cy + 120) then
                    carta.selecionada = not carta.selecionada
                    break
                end
            end
            
        elseif estado_jogo == "venceu_nivel" then
            --botao para o proximo nivel
            local btn_x, btn_y, btn_w, btn_h = 540, 400, 250, 60
            if x >= btn_x and x <= (btn_x + btn_w) and y >= btn_y and y <= (btn_y + btn_h) then
                nivel_atual = nivel_atual + 1
                alvo_nivel = alvo_nivel * 2.5 
                pontuacao_atual = 0
                ultima_jogada_nome = ""
                iniciarNivel()
            end
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

    ultimas_fichas = fichas
    ultimo_mult = mult
    total_ganho = fichas * mult
    pontuacao_atual = pontuacao_atual + total_ganho

    comprarCartas(#cartas_jogadas)
end

function love.draw()
    --fundo verde
    love.graphics.setBackgroundColor(0.2, 0.45, 0.25)
    
   --painel que fica na esquerda
    love.graphics.setColor(0.15, 0.15, 0.15) 
    love.graphics.rectangle("fill", 0, 0, painel_w, 720)
    
    love.graphics.setColor(1, 1, 1)
    love.graphics.setNewFont(28)
    love.graphics.print("Nível " .. nivel_atual, 20, 30)
    
    
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
    love.graphics.print("Alvo do Nível", 30, 210)
    love.graphics.setNewFont(40)
    love.graphics.setColor(0.9, 0.2, 0.2) 
    love.graphics.print(math.floor(alvo_nivel), 30, 240)

    --dadod da run
    love.graphics.setColor(1, 1, 1)
    love.graphics.setNewFont(20)
    love.graphics.print("Cartas no Baralho: " .. #baralho, 20, 650)

--are ada mesa 
    if estado_jogo == "jogando" then
        
        
        if ultima_jogada_nome ~= "" then
            love.graphics.setColor(1, 1, 1)
            love.graphics.setNewFont(24)
            love.graphics.printf(ultima_jogada_nome, painel_w, 150, 1280 - painel_w, "center")
            
            --caixa para fichas
            love.graphics.setColor(0.1, 0.5, 0.9)
            love.graphics.rectangle("fill", 520, 200, 100, 60, 8)
            love.graphics.setColor(1, 1, 1)
            love.graphics.printf(ultimas_fichas, 520, 215, 100, "center")
            
            --x que fica no centro
            love.graphics.setColor(1, 1, 1)
            love.graphics.printf("X", 620, 215, 60, "center")
            
            --caixa vermelha
            love.graphics.setColor(0.9, 0.2, 0.2)
            love.graphics.rectangle("fill", 680, 200, 100, 60, 8)
            love.graphics.setColor(1, 1, 1)
            love.graphics.printf(ultimo_mult, 680, 215, 100, "center")
            
            --ganho quando jogar
            love.graphics.setColor(1, 1, 0.2)
            love.graphics.printf("+ " .. total_ganho, painel_w, 280, 1280 - painel_w, "center")
        end

        --botao de jogar a mao
        love.graphics.setColor(0.9, 0.6, 0.1)
        love.graphics.rectangle("fill", 600, 350, 160, 60, 8)
        love.graphics.setColor(0, 0, 0)
        love.graphics.setNewFont(24)
        love.graphics.print("JOGAR", 640, 365)

        --desenho da mao
        local inicio_x = painel_w + 50
        for i, carta in ipairs(mao) do
            local x = inicio_x + (i - 1) * 95
            local y = 500
            
            if carta.selecionada then y = y - 20 end
            
            love.graphics.setColor(1, 1, 1) 
            love.graphics.rectangle("fill", x, y, 80, 120, 8, 8)
            
            love.graphics.setColor(0, 0, 0)
            love.graphics.setLineWidth(2)
            love.graphics.rectangle("line", x, y, 80, 120, 8, 8)
            
            love.graphics.setNewFont(36) 
            local offset_x = (carta.valor >= 10) and 20 or 30 
            love.graphics.print(carta.valor, x + offset_x, y + 40)
        end

    elseif estado_jogo == "venceu_nivel" then
        --tela de nivel
        love.graphics.setColor(0, 0, 0, 0.8)
        love.graphics.rectangle("fill", painel_w, 0, 1280 - painel_w, 720)
        
        love.graphics.setColor(1, 1, 1)
        love.graphics.setNewFont(48)
        love.graphics.printf("NÍVEL " .. nivel_atual .. " SUPERADO!", painel_w, 250, 1280 - painel_w, "center")
        
        love.graphics.setColor(0.2, 0.8, 0.2)
        love.graphics.rectangle("fill", 540, 400, 250, 60, 10)
        love.graphics.setColor(1, 1, 1)
        love.graphics.setNewFont(24)
        love.graphics.print("PRÓXIMO NÍVEL", 565, 415)
    end
end