# NMS Controle Financeiro

Aplicativo de controle financeiro pessoal (PF) e empresarial (PJ), instalável no computador e no celular.

## O que ele faz

**Pessoa física**
- Painel do mês com entradas, saídas, saldo e saldo projetado
- Avisos de gasto por limite (ex.: iFood), no tom normal ou bravo
- Agenda de contas com botão "Paguei"
- Gráfico de pizza por categoria, com detalhe ao tocar
- Importação de extrato (OFX, CSV, Excel e PDF/texto do Banco do Brasil), com classificação automática
- Calendário de capital

**Empresa**
- Contas a pagar e a receber, com fornecedores e clientes cadastrados
- Compras parceladas e contratos mensais
- DRE fácil (cascata do faturamento ao lucro) e DRE completo (EBITDA, AV %, AH %)
- Indicadores: margens, ponto de equilíbrio, burn rate, runway, liquidez e fluxo de caixa de 30 dias

**Bancos e cartões** (PF e empresa)
- Contas bancárias com saldo próprio; cada conta a pagar e cada lançamento escolhe de qual banco sai (campo "Pagar com")
- Transferências entre contas do mesmo dono (origem e destino), sem contar como receita ou despesa
- Cartões de crédito com dia de fechamento e vencimento: despesas no cartão, fatura de cada mês e pagamento da fatura escolhendo a conta que pagou
- Na importação de extrato, dá para dizer de qual conta ou cartão é o arquivo

**Geral**
- Login por e-mail com conta Pessoal ou Empresa
- Acesso Master para ver todos os usuários
- Funciona como aplicativo instalado (PWA), com aviso de nova versão

## Estrutura

| Arquivo | Para que serve |
|---|---|
| `index.html` | O aplicativo |
| `config.js` | Endereço e chave do Supabase, e número da versão |
| `nms-cloud.js` | Conexão com o banco de dados (Supabase) |
| `diagnostico.html` | Diagnóstico e precificação de clientes da NMS (só para quem está em `nms_config.diagnostico_uids`) |
| `sw.js` | Funcionamento offline e atualização automática |
| `manifest.webmanifest`, `icons/` | Instalação como aplicativo |
| `supabase/schema.sql` | Criação do banco e das regras de segurança |
| `marca/` | Logo do NMS |
| `COMO-PUBLICAR.txt` | Passo a passo completo de publicação |

## Rodar no computador

Sem configurar nada, o app abre em modo demonstração com dados fictícios:

```
python3 -m http.server 8080
```

Depois abra http://localhost:8080 no navegador.

## Publicar

Siga o `COMO-PUBLICAR.txt`. Com o repositório no GitHub, o Netlify pode publicar sozinho a cada alteração: em **Add new site > Import an existing project > GitHub**, escolha este repositório (diretório de publicação: `/`, sem comando de build).

Para lançar uma versão nova, aumente o número em `config.js` (`versao`) e em `sw.js` (`VERSAO`). Quem instalou o app recebe o aviso "Nova versão disponível".

## Segurança

- A chave `anon public` do Supabase pode ficar no `config.js`; os dados de cada usuário são protegidos pelas regras do `schema.sql`.
- Nunca coloque a chave `service_role` neste repositório.
- Este repositório é público: dados pessoais e bancários da NMS (CPF, conta, Pix, endereço) ficam só no banco, na configuração do diagnóstico, nunca no código.
