-- main.lua

local baralho = {}
local mao = {}
local max_mao = 8

function love.load()
    math.randomseed(os.time())
    love.graphics.setBackgroundColor(0.1, 0.4, 0.2)
    
    criarBaralho()
    embaralhar()
    comprarCartas(max_mao)
end

function criarBaralho()
    for copia = 1, 4 do
        for valor = 1, 10 do
            -- NOVIDADE: Adicionamos o estado "selecionada"
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
            local carta_comprada = table.remove(baralho)
            table.insert(mao, carta_comprada)
        end
    end
end

function love.update(dt)
end

-- NOVIDADE: Função nativa do LÖVE para detectar clique do mouse
function love.mousepressed(x, y, button, istouch, presses)
    -- Se foi o botão esquerdo do mouse (1)
    if button == 1 then
        local largura_carta = 80
        local altura_carta = 120
        local espacamento = 15
        local inicio_x = 20
        local inicio_y = 490

        -- Vamos checar carta por carta para ver se o mouse bateu nela
        for i, carta in ipairs(mao) do
            local carta_x = inicio_x + (i - 1) * (largura_carta + espacamento)
            local carta_y = inicio_y
            
            -- Se a carta já estava levantada, o Hitbox dela também sobe!
            if carta.selecionada then
                carta_y = carta_y - 20
            end

            -- Lógica de colisão (Hitbox): O mouse está dentro dos limites do retângulo?
            if x >= carta_x and x <= (carta_x + largura_carta) and
               y >= carta_y and y <= (carta_y + altura_carta) then
                
                -- Inverte o status da carta (se era false vira true, se era true vira false)
                carta.selecionada = not carta.selecionada
                break -- Achamos a carta clicada, paramos de procurar
            end
        end
    end
end

function love.draw()
    love.graphics.setNewFont(20)
    love.graphics.setColor(1, 1, 1)
    
    love.graphics.print("Cartas no Baralho: " .. #baralho, 20, 20)
    love.graphics.print("Sua Mão:", 20, 450)
    
    local largura_carta = 80
    local altura_carta = 120
    local espacamento = 15
    local inicio_x = 20
    local inicio_y = 490
    
    for i, carta in ipairs(mao) do
        local x = inicio_x + (i - 1) * (largura_carta + espacamento)
        local y = inicio_y
        
        -- NOVIDADE: Se estiver selecionada, subtrai 20 pixels da posição Y (faz ela subir)
        if carta.selecionada then
            y = y - 20
        end
        
        love.graphics.setColor(1, 1, 1) 
        love.graphics.rectangle("fill", x, y, largura_carta, altura_carta, 10, 10)
        
        love.graphics.setColor(0, 0, 0)
        love.graphics.setLineWidth(2)
        love.graphics.rectangle("line", x, y, largura_carta, altura_carta, 10, 10)
        
        love.graphics.setNewFont(32) 
        local offset_x = (carta.valor >= 10) and 20 or 30 
        love.graphics.print(carta.valor, x + offset_x, y + 40)
    end
end