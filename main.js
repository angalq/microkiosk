const { electron, app, dialog, globalShortcut, session, BrowserWindow } = require('electron')
const { exec } = require('child_process')
const os = require('os')
const path = require('path')

// Deve-se manter uma referência global de objeto BrowserWindow, evitando
// que a janela seja fechada quando o JavaScript executar o garbage colletor
let mainWindow

function createBrowser () {
    // Limpa o cache e o banco de dados antes de iniciar a aplicação
    session.defaultSession.clearCache(() => {})
    session.defaultSession.clearStorageData()
    session.defaultSession.setProxy({
        pacScript: 'http://proxy.prevnet/proxy.pac'
    }, () => {})
    
    // Cria uma instância global de objeto BrowserWindow
    mainWindow = new BrowserWindow({
        fullscreen: true,
        resizable: true, // True para compatibilidade com Openbox, senão a janela não fica fullscreen
        minimizable: false, 
        maximizable: false, 
        kiosk: true,
        webPreferences: {
            sandbox: true, 
            plugins: false, // Habilita os plugins nativos do Chromium para a visualização do PDF
            nodeIntegration: true // Habilita integração para permitir execução do comando de impressão
        } 
    })

    mainWindow.loadURL('https://meu.inss.gov.br')

    // Emitted when the window is closed.
    mainWindow.on('closed', function () {
        // Dereference the window object, usually you would store windows
        // in an array if your app supports multi windows, this is the time
        // when you should delete the corresponding element.
        mainWindow = null
        app.exit(0)
    })

    globalShortcut.register('F5', () => { // Define a tecla F5 para reiniciar o aplicativo
        app.relaunch() // Cria o processo da aplicação
        app.exit(0) // Encerra o processo corrente, permitindo que o novo processo seja ativado
    })

    // Habilita um listener para identificar pedido de impressão de PDF. 
    // Em ambiente Windows, o PDF é impresso com o utilitário PDFtoPrinter.exe, visível na variável PATH
    // Em ambiente Linux, o PDF é impresso ld, considerando que a impressora instalada possui o nome DefaultPrinter
    mainWindow.webContents.session.on('will-download', function(event, item, webContents) {
        let filePath = path.format({
            dir: os.tmpdir(),
            base: 'export.pdf'
        })
        item.setSavePath(filePath)
        item.once('done', (event, state) => {
            if (state === 'completed') {
                // Imprime de acordo com o ambiente nativo.
                // Os ambientes suportados são Windows e Linux
                switch (os.platform()) {
                    case 'win32':
                        exec('wmic printer where default=true get deviceid /value', (error, stdout, stderr) => {
                            if (error) {
                                dialog.showMessageBox(mainWindow, {
                                    type: 'error',
                                    buttons: ['OK'],
                                    message: 'Impressora não identificada'
                                })
                                return;
                            }
                            let deviceId = stdout.replace('DeviceID=', '').replace(/\r/g, '').replace(/\n/g, '')
                            let command = 'PDFtoPrinter.exe'.concat(' ').concat(filePath).concat(' ').concat(deviceId)
                            exec(command, (error, stdout, stderr) => {
                                if (error) {
                                    dialog.showMessageBox(mainWindow, {
                                        type: 'error',
                                        buttons: ['OK'],
                                        message: 'Falha no comando de impressão'
                                    })
                                    return
                                } else {
                                    dialog.showMessageBox(mainWindow, {
                                        type: 'info',
                                        buttons: ['OK'],
                                        message: 'Seu documento sairá na impressora em até 10 segundos!'
                                    }) 
                                }
                            })
                        })
                    break
                    case 'linux' :
                        let command = 'lp'.concat(' -d DefaultPrinter ').concat(filePath)
                        exec(command, (error, stdout, stderr) => {
                            if (error) {
                                dialog.showMessageBox(mainWindow, {
                                    type: 'error',
                                    buttons: ['OK'],
                                    message: 'Falha no comando de impressão'
                                })
                                return
                            } else {
                                dialog.showMessageBox(mainWindow, {
                                    type: 'info',
                                    buttons: ['OK'],
                                    message: 'Seu documento sairá na impressora em até 10 segundos!'
                                }) 
                            }
                        })
                }
            }
        })
    })
}

// This method will be called when Electron has finished
// initialization and is ready to create browser windows.
// Some APIs can only be used after this event occurs.
app.on('ready', createBrowser)

app.on('browser-window-created', function(e, appWindow){
    appWindow.setMenu(null) // Desabilita o menu de aplicação padrão do Electron
    if (mainWindow) { // Toda janela extra é filha da janela principal
        appWindow.setParentWindow = mainWindow
    }
})

app.on('activate', function () {
    // On OS X it's common to re-create a window in the app when the
    // dock icon is clicked and there are no other windows open.
    if (mainWindow === null) {
        createBrowser()
    }
})

app.on('certificate-error', (event, webContents, url, error, certificate, callback) => {
    // Ignora erros de certificado
    event.preventDefault()
    callback(true)
})