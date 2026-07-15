# 🚀 Atalhos

Coleção de scripts para automatizar tarefas do Windows e facilitar o dia a dia.

## 📋 Como executar

1. Pressione **Win + R** para abrir o **Executar**.
2. Copie e cole um dos comandos abaixo.
3. Pressione **Ctrl + Shift + Enter** (ou **Ctrl + Enter**, dependendo da configuração do sistema) para executar com privilégios de administrador.
4. Confirme a solicitação do UAC, caso seja exibida.

---

## ⚡ Quick

```powershell
powershell -WindowStyle Hidden -NoProfile -ExecutionPolicy Bypass -Command "iwr -useb https://raw.githubusercontent.com/ThiMnano/nano/main/Quick.ps1 | iex"
```

---

## 🛠️ Atalhos

```powershell
powershell -WindowStyle Hidden -NoProfile -ExecutionPolicy Bypass -Command "iwr -useb https://raw.githubusercontent.com/ThiMnano/nano/main/atalhos.ps1 | iex"
```

---

## ✨ Atalhos V2

```powershell
powershell -WindowStyle Hidden -NoProfile -ExecutionPolicy Bypass -Command "iwr -useb https://raw.githubusercontent.com/ThiMnano/nano/main/Atalhos_v2.ps1 | iex"
```

---

## 🐘 Restaurar PostgreSQL

```powershell
powershell -WindowStyle Hidden -NoProfile -ExecutionPolicy Bypass -Command "iwr -useb https://raw.githubusercontent.com/ThiMnano/nano/main/RestaurarPostgres.ps1 | iex"
```

---

## 🔒 O que este comando faz?

Todos os comandos utilizam o mesmo padrão:

- **PowerShell** em modo oculto (`-WindowStyle Hidden`)
- Sem carregar o perfil do usuário (`-NoProfile`)
- Ignora temporariamente a política de execução (`-ExecutionPolicy Bypass`)
- Baixa o script diretamente do GitHub (`Invoke-WebRequest`)
- Executa o script imediatamente (`Invoke-Expression`)

---

## 📌 Requisitos

- Windows 10 ou superior
- PowerShell 5.1 ou superior
- Conexão com a internet
- Permissão de administrador (recomendado)