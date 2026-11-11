# REPO CONTEXT — Talento Digital (IASD Recanto)

Este documento foi elaborado especificamente para que agentes de inteligência artificial e desenvolvedores compreendam a fundo o propósito, regras de negócio, arquitetura técnica e padrões do projeto **Talento Digital**.

---

## 1. Visão Geral e Domínio de Negócio

### 1.1 O que é o Talento Digital?
O **Talento Digital** é um sistema de gamificação e economia simbólica (economia de fichas) desenvolvido para a comunidade da **IASD Recanto** (Igreja Adventista do Sétimo Dia do Recanto das Emas).

O objetivo principal é incentivar a frequência, pontualidade, dedicação aos estudos bíblicos e participação das crianças e adolescentes nas atividades comunitárias.

### 1.2 Vocabulário do Domínio
- **Aluno:** Criança ou adolescente participante das atividades.
- **Talento (moeda):** Unidade de pontuação digital. Não tem valor monetário real em R$, mas tem valor de troca interno.
- **Tag NFC / UID:** Cartão ou chaveiro de aproximação físico portado pelo aluno. Possui um identificador hexadecimal único (geralmente 14 caracteres hexadecimais).
- **UID Manual (`MANUAL_xxx`):** Identificador provisório gerado pelo sistema para cadastrar um aluno que ainda não recebeu sua tag física. Pode ser convertido em tag real posteriormente via `vincularTagAoAluno`.
- **Feirinha / Lojinha:** Evento periódico onde os alunos utilizam seus talentos acumulados para adquirir lanches, brinquedos, materiais escolares e brindes.
- **PDV (Ponto de Venda):** Interface rápida de caixa operada pelos voluntários para selecionar produtos e debitar talentos encostando o cartão do aluno.
- **Transação de Saldo:** Registro histórico de movimentação (`ENTRADA`, `SAIDA` ou `AJUSTE`) associado a um motivo (ex: "Presença", "Lição da semana", "Compra na Cantina") e ao operador responsável.

---

## 2. Arquitetura Técnica

```
                    ┌───────────────────────────────────┐
                    │          Flutter UI Layer         │
                    │   (AlunosScreen, FeirinhaPdv,     │
                    │    Modais & Diálogos de Gestão)   │
                    └─────────────────┬─────────────────┘
                                      │
                         ┌────────────┴────────────┐
                         │                         │
                         ▼                         ▼
             ┌───────────────────────┐ ┌───────────────────────┐
             │    NfcUsbListener     │ │  PinSecurityService   │
             │ (Leitor USB / Teclado)│ │ (Autenticação por PIN)│
             └───────────────────────┘ └───────────────────────┘
                                      │
                                      ▼
                    ┌───────────────────────────────────┐
                    │        TalentosRepository         │
                    │ (Single Source of Truth / Façade) │
                    └─────────────────┬─────────────────┘
                                      │
            ┌─────────────────────────┴─────────────────────────┐
            │                                                   │
            ▼ (Primário)                                        ▼ (Fallback)
┌──────────────────────────────────────┐            ┌───────────────────────────────┐
│     Google Cloud Firestore           │            │       SQLite Local            │
│  - Persistência Offline Ativa        │            │  (sqflite / sqflite_common)   │
│  - Cache Ilimitado                   │            │  - Usado em dev Linux Desktop │
│  - Transações Atômicas (WriteBatch)  │            └───────────────────────────────┘
│  - Streams em Tempo Real             │
└──────────────────────────────────────┘
```

### 2.1 Banco de Dados Primário: Google Cloud Firestore
- **Projeto Firebase:** `talentos-f34f3` (configurado em [firebase_options.dart](file:///home/loko/Documentos/IASD_Recanto/Talento%20digital/lib/firebase_options.dart)).
- **Configuração de Cache Offline:** No [main.dart](file:///home/loko/Documentos/IASD_Recanto/Talento%20digital/lib/main.dart), a persistência está explicitamente ligada:
  ```dart
  FirebaseFirestore.instance.settings = const Settings(
    persistenceEnabled: true,
    cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
  );
  ```
- **Comportamento Offline-First:** Toda gravação (`set`, `update`, `batch.commit`) é aplicada imediatamente no cache local do dispositivo e replicada na nuvem em segundo plano assim que houver conexão.
- **Escritas Atômicas:** A dedução de estoque e débito de talentos utiliza `WriteBatch` e `FieldValue.increment` para evitar condições de corrida (race conditions) em múltiplos caixas simultâneos.

### 2.2 Fallback de Desenvolvimento: SQLite
- Mantido em [app_database.dart](file:///home/loko/Documentos/IASD_Recanto/Talento%20digital/lib/database/app_database.dart).
- Se o app for executado diretamente no Linux Desktop (`flutter run -d linux`), onde o Firestore não possui plugin oficial em C++, o repositório usa o SQLite local de forma transparente para permitir desenvolvimento rápido sem quebrar. No Chrome (`web`) e no Android, o Firestore atua nativamente.

---

## 3. Esquema de Coleções do Cloud Firestore

### 3.1 Coleção `alunos`
- **Document ID:** `uid` da tag (ex: `04A1B2C3` ou `MANUAL_1731195600000`).
- **Campos:**
  - `uid` (String): ID único do aluno / UID do cartão.
  - `nome` (String): Nome completo do aluno.
  - `turma` (String?): Nome da classe/departamento (ex: "Primários", "Juvenis").
  - `saldo_talentos` (int): Quantidade atual de talentos disponíveis. Nunca pode ser negativo.
  - `ativo` (bool / int): Status do aluno (1 / true para ativo).
  - `updated_at` (String ISO8601): Data da última modificação.

### 3.2 Coleção `produtos`
- **Document ID:** `id` (String com o ID numérico, ex: `"1"`, `"1731195610"`).
- **Campos:**
  - `id` (int): Identificador do produto.
  - `nome` (String): Nome do produto (ex: "Suco", "Bolo", "Caneta").
  - `valor_talentos` (int): Preço em talentos.
  - `estoque` (int): Quantidade disponível.
  - `esgotado` (bool / int): Indicador se o item acabou.
  - `updated_at` (String ISO8601): Data da última alteração.

### 3.3 Coleção `transacoes_saldo`
- **Document ID:** `id` (UUID v4).
- **Campos:**
  - `id` (String UUID): ID da transação.
  - `aluno_uid` (String): UID do aluno envolvido.
  - `tipo` (String): `'ENTRADA'` (crédito), `'SAIDA'` (débito/compra), `'AJUSTE'`.
  - `quantidade` (int): Valor absoluto movimentado.
  - `motivo` (String): Descrição da motivação (ex: "Pontualidade", "Feirinha").
  - `operador` (String): Nome do professor/caixa responsável.
  - `created_at` (String ISO8601): Timestamp da ocorrência.

### 3.4 Coleção `vendas`
- **Document ID:** `id` (UUID v4).
- **Campos:**
  - `id` (String UUID): Identificador da venda.
  - `aluno_uid` (String): UID do aluno comprador.
  - `total_talentos` (int): Somatório total de talentos pagos.
  - `created_at` (String ISO8601): Data/hora da venda.
  - `itens` (Array de Objetos):
    ```json
    [
      {
        "produto_id": 1,
        "descricao_livre": null,
        "quantidade": 2,
        "preco_unitario": 5
      }
    ]
    ```

---

## 4. Hardware e Pipeline de Captura NFC

### 4.1 Leitores USB Plug-and-Play (Emulação de Teclado HID)
- A maioria dos leitores RFID/NFC USB comerciais (como ACR122U configurado ou leitores genéricos de 13.56 MHz) opera como um teclado físico: ao encostar o cartão, o hardware "digita" rapidamente a sequência hexadecimal (normalmente 14 dígitos) e envia a tecla `Enter`.
- O serviço [nfc_usb_listener.dart](file:///home/loko/Documentos/IASD_Recanto/Talento%20digital/lib/services/nfc_usb_listener.dart) intercepta esses eventos no nível global do Flutter via `HardwareKeyboard.instance.addHandler`.
- **Mecanismo LIFO (Last In, First Out):**
  - Múltiplas telas e modais podem registrar ouvintes NFC simultaneamente.
  - O ouvinte mais recente (topo da pilha) tem prioridade exclusiva. Exemplo: se o modal de checkout do PDV estiver aberto, a leitura é direcionada exclusivamente para ele, sem disparar a tela de alunos que está em segundo plano.

### 4.2 Web NFC e Mobile NFC
- Suporte a `nfc_manager` para dispositivos móveis nativos (Android/iOS).
- Suporte a [web_nfc_helper.dart](file:///home/loko/Documentos/IASD_Recanto/Talento%20digital/lib/services/web_nfc_helper.dart) via `dart:js_interop` para navegadores que implementam Web NFC.

---

## 5. Regras de Negócio Críticas (Invariantes)

Ao implementar ou alterar qualquer parte do código, **respeite estritamente estas regras**:

1. **Saldo Não Negativo:**
   - Em qualquer operação de débito (`adicionarTalentos` com valor negativo ou `processarVenda`), o saldo do aluno **jamais** pode ficar menor que zero. Se o saldo for insuficiente, lance obrigatoriamente `SaldoInsuficienteException`.
2. **Atomicidade no Checkout:**
   - No `processarVenda`:
     1. Valida saldo do aluno.
     2. Debita saldo do aluno.
     3. Cria documento em `transacoes_saldo`.
     4. Cria documento em `vendas` com os itens.
     5. Decrementa o estoque de cada produto via `FieldValue.increment(-quantidade)`.
   - Todas essas operações devem ocorrer em conjunto (`WriteBatch`).
3. **Resiliência a Tipagem nos Modelos:**
   - Como documentos no Firestore podem conter campos salvos como `bool` (`true`/`false`) ou `num` (`1`/`0`), o método `fromMap` de todos os modelos deve sempre validar ambos os formatos (ver [models.dart](file:///home/loko/Documentos/IASD_Recanto/Talento%20digital/lib/database/models.dart)).
4. **Proteção Administrativa por PIN:**
   - O painel de gestão de produtos, alteração de PIN e painel administrativo exigem chamada prévia a `PinAuthDialog.solicitarPin(context)`. O PIN padrão inicial é `1234`.

---

## 6. Mapa dos Arquivos do Código-Fonte

| Arquivo | Papel / Responsabilidade |
| :--- | :--- |
| `lib/main.dart` | Ponto de entrada, inicialização do Firebase com cache e setup do app |
| `lib/firebase_options.dart` | Credenciais multi-plataforma geradas pelo FlutterFire CLI |
| `lib/database/models.dart` | Classes `AlunoModel`, `ProdutoModel`, `TransacaoSaldoModel`, `VendaModel`, `ItemVendaDto` e exceptions |
| `lib/database/talentos_repository.dart` | Camada de dados única (Firestore + cache e fallback local) |
| `lib/database/app_database.dart` | Configuração do SQLite local para testes e desenvolvimento offline |
| `lib/screens/alunos_screen.dart` | Tela inicial: busca em tempo real, lista de alunos, leitor NFC e atalhos |
| `lib/screens/feirinha_pdv_screen.dart` | Ponto de venda: catálogo visual, carrinho, cálculo de total e checkout |
| `lib/screens/admin_painel_dialog.dart` | Painel de status do Firebase, métricas gerais e atalhos de gestão |
| `lib/widgets/aluno_detalhes_modal.dart` | Exibe histórico, saldo e botões rápidos (+1, +2, +5, +10) de talentos |
| `lib/widgets/gestao_produtos_dialog.dart` | CRUD de produtos da lojinha e controle de estoque/esgotado |
| `lib/widgets/nova_tag_dialog.dart` | Diálogo exibido ao aproximar tag ainda não cadastrada |
| `lib/widgets/pdv_checkout_dialog.dart` | Modal de confirmação de pagamento do PDV aguardando aproximação do cartão |
| `lib/widgets/pin_auth_dialog.dart` | Teclado virtual na tela para digitação do PIN administrativo |
| `lib/services/nfc_usb_listener.dart` | Listener de teclado físico com buffer e debounce para tags NFC |
| `lib/services/pin_security_service.dart` | Gerenciador do PIN criptografado/persistido em `SharedPreferences` |

---

## 7. Comandos de Verificação e Manutenção

Sempre que efetuar alterações no repositório, execute estes comandos no terminal:

```bash
# 1. Checar análise estática (sempre deve retornar 'No issues found!')
flutter analyze

# 2. Executar suíte completa de testes unitários e de widget
flutter test

# 3. Rodar no navegador para validação visual rápida do Firestore
flutter run -d chrome
```

---

## 8. Orientações para Próximas Etapas

Caso a próxima etapa do desenvolvimento envolva:
- **Relatórios / Exportação:** Crie serviços dedicados em `lib/services/` (ex: exportação CSV/PDF das vendas ou balanço de talentos) consumindo os métodos de listagem do `TalentosRepository`.
- **Autenticação de Usuários:** Se for adicionar login de professores via Firebase Auth, configure em `lib/services/auth_service.dart` e passe o operador logado para os métodos de transação (`operador: currentUser.name`).
- **Novas coleções:** Adicione o modelo correspondente em `lib/database/models.dart` e exponha os métodos de leitura/escrita no `TalentosRepository`.
