const { electron, app, dialog, globalShortcut, session, BrowserWindow } = require('electron')
const { exec } = require('child_process')
const os = require('os')
const path = require('path')

// Keep a global reference for BrowserWindow, avoid garbage collector close.
let mainWindow

function createBrowser() {
    // Clean cache and database before start
    session.defaultSession.clearCache(() => { })
    session.defaultSession.clearStorageData()

    // Cria uma instância global de objeto BrowserWindow
    // Create the global instance of BrowserWindow
    mainWindow = new BrowserWindow({
        fullscreen: true,
        resizable: true, // True for Openbox compatibility, otherwise there is no fullscreen window
        minimizable: false,
        maximizable: false,
        kiosk: true,
        show: false, // Hide the window until the event ready-to-show
        webPreferences: {
            sandbox: true,
            plugins: false, // Enable native plugins to view PDF
            nodeIntegration: true // Enable native integration to execute print command
        }
    })

    // Show the window when ready-to-show event is triggered
    mainWindow.once('ready-to-show', () => {
        mainWindow.show()
    })

    mainWindow.loadURL('https://www.google.com')

    mainWindow.on('closed', function () {
        mainWindow = null
        app.exit(0)
    })

    // Define F5 key to restar application
    globalShortcut.register('F5', () => { 
        app.relaunch() 
        app.exit(0) // Close current process
    })

    // Set a listener to print PDF
    // In Linux, the PDF is printed with 'ld' command
    // and the printer has 'DefaultPrinter' name
    mainWindow.webContents.session.on('will-download', function (event, item, webContents) {
        let filePath = path.format({
            dir: os.tmpdir(),
            base: 'export.pdf'
        })
        item.setSavePath(filePath)
        item.once('done', (event, state) => {
            if (state === 'completed') {
                switch (os.platform()) {
                    case 'linux':
                        let command = 'lp'.concat(' -d DefaultPrinter ').concat(filePath)
                        exec(command, (error, stdout, stderr) => {
                            if (error) {
                                dialog.showMessageBox(mainWindow, {
                                    type: 'error',
                                    buttons: ['OK'],
                                    message: 'Printer command failure'
                                })
                                return
                            } else {
                                dialog.showMessageBox(mainWindow, {
                                    type: 'info',
                                    buttons: ['OK'],
                                    message: 'Your PDF is been printed'
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

app.on('browser-window-created', function (e, appWindow) {
    appWindow.setMenu(null) // Disable default Eletron menu
    if (mainWindow) { // Every window is a child window
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
    // Ignore certificate errors
    event.preventDefault()
    callback(true)
})
