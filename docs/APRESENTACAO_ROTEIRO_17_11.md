# Roteiro Simples de Apresentação — CacauApp2 (17/11/2026)

> Guia rápido de fala em linguagem simples para os 5 integrantes apresentarem o `Apresentacao_CacauApp2_17_11.pdf` (10 slides), sem termos técnicos pesados.

---

## Divisão Sugerida por Pessoa (2 slides cada — cerca de 5 a 7 minutos no total)

### Pessoa 1 — Slides 1 e 2 (Abertura, Problema e Solução)
- **Slide 1:** *"Nosso projeto é o CacauApp2. Ele junta um aplicativo de celular offline com Inteligência Artificial e um banco de dados seguro e rápido para acompanhar fazendas de cacau."*
- **Slide 2:** *"Hoje na pesquisa do cacau, os técnicos precisam contar os frutos e olhar doenças pé por pé na roça, onde quase nunca tem internet. Anotar tudo no papel dá trabalho e gera erro. O CacauApp2 resolve isso usando a câmera do celular sem internet: ele detecta e conta os frutos na hora, o técnico confere na tela, segue o roteiro de plantas e manda os dados organizados para um banco protegido."*

### Pessoa 2 — Slides 3 e 4 (Evolução desde 27/10 e Como a IA Funciona)
- **Slide 3:** *"Desde a entrega de outubro, saímos de um rascunho de banco no papel para um banco funcionando de verdade com mais de 100 mil registros fictícios, segurança aplicada e testes reais da IA. Falta apenas ligar o envio direto do celular pela rede local, ampliar fotos raras na sombra e gravar o vídeo demonstrativo."*
- **Slide 4:** *"Aqui está o caminho da foto dentro do app: o sistema ajusta a imagem, clareia quando a foto foi tirada debaixo de sombra escura e conta os frutos sem internet. Na versão 2 melhoramos a detecção para não perder frutos pequenos na sombra e não contar o mesmo fruto duas vezes. Todos os 6 testes reais passaram, inclusive a foto só com folhas sem nenhum falso positivo."*

### Pessoa 3 — Slides 5 e 6 (Treino da IA e Segurança por Perfis)
- **Slide 5:** *"Um modelo comum de fábrica não conhece cacau — nos nossos testes ele errou tudo e confundiu cacau com maçã e laranja. Depois do treinamento específico para cacau, a taxa de acerto chegou a 94,2%, acertando 39 frutos e zero erros nas folhas. E tudo roda offline no celular em menos de 0,3 segundo por foto, com custo zero de servidor."*
- **Slide 6:** *"No banco de dados, ninguém tem acesso livre. Dividimos em 4 perfis com 19 de 19 testes aprovados: o Técnico só lança coletas e vê sua fazenda; o Auditor fiscaliza todas as fazendas sem ver senhas e com CPF escondido; a IA só grava contagens novas; e apenas o Administrador vê o cadastro completo e acompanha a auditoria."*

### Pessoa 4 — Slides 7 e 8 (Proteção de Dados Pessoais e Otimização de Velocidade)
- **Slide 7:** *"Além dos perfis, protegemos os dados sensíveis de três jeitos: CPF e e-mail ficam mascarados na tela do auditor, as senhas ficam gravadas de forma embaralhada e bloqueadas contra leitura, e existe uma regra automática que separa fazenda por fazenda — quem trabalha na Fazenda 1 nunca enxerga nada da Fazenda 2."*
- **Slide 8:** *"Testamos o banco com 100.003 coletas simuladas. Antes dos índices, toda busca lia a tabela inteira (1.796 páginas). Depois que criamos 2 índices organizados, a primeira busca caiu para 68 páginas (96% menos esforço) e a segunda caiu para apenas 3 páginas, respondendo em menos de 1 milissegundo."*

### Pessoa 5 — Slides 9 e 10 (Integração Segura, Auditoria e Fechamento)
- **Slide 9:** *"Quando a Inteligência Artificial conversa com o banco, ela sempre assume as limitações de quem pediu. Se alguém tentar puxar CPFs, apagar registros ou mandar um comando malicioso no texto, o sistema bloqueia na hora e deixa tudo anotado na auditoria: quem pediu, o perfil, o horário e se foi permitido ou negado."*
- **Slide 10:** *"Resumindo: temos um aplicativo offline funcional na roça, IA treinada especificamente para cacau, banco protegido por perfis e filtros de privacidade, e buscas até 99,8% mais leves. Obrigado!"*
