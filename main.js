const { electron, app, dialog, globalShortcut, session, BrowserWindow } = require('electron')
const { exec } = require('child_process')
const os = require('os')
const path = require('path')

// Keeping a globa referente to BrowserWindow avoid that JavaScript garbage collect the window
let mainWindow

function createBrowser () {
    // Clean cache and local data before start
    session.defaultSession.clearCache(() => {})
    session.defaultSession.clearStorageData()
    session.defaultSession.setProxy({
        pacScript: 'http://localhost/proxy.pac'
    }, () => {})
    
    // Create the global instance of BrowserWindow
    mainWindow = new BrowserWindow({
        fullscreen: true,
        resizable: true, // True for compatibility with Openbox, otherwise the window won't be fullscreen
        minimizable: false, 
        maximizable: false, 
        kiosk: true,
        webPreferences: {
            sandbox: true, 
            plugins: false, // Activate Chromium plugins for PDF view
            nodeIntegration: true // Activate NodeJS integration for print service
        } 
    })

    mainWindow.loadURL('https://www.google.com.br') // The kiosk web page

    // Emitted when the window is closed.
    mainWindow.on('closed', function () {
        // Dereference the window object, usually you would store windows
        // in an array if your app supports multi windows, this is the time
        // when you should delete the corresponding element.
        mainWindow = null
        app.exit(0)
    })

    globalShortcut.register('F5', () => { // Define F5 key to restart the app
        app.relaunch() // Recreate the app
        app.exit(0) // Close the current app.
    })

    // Enable a listener to directly prin PDF
    // In Linux, the default printer must have the name DefaultPrinter
    mainWindow.webContents.session.on('will-download', function(event, item, webContents) {
        let filePath = path.format({
            dir: os.tmpdir(),
            base: 'export.pdf'
        })
        item.setSavePath(filePath)
        item.once('done', (event, state) => {
            if (state === 'completed') {
                // The only supported environment is Linux
                switch (os.platform()) {
                    case 'linux' :
                        let command = 'lp'.concat(' -d DefaultPrinter ').concat(filePath)
                        exec(command, (error, stdout, stderr) => {
                            if (error) {
                                dialog.showMessageBox(mainWindow, {
                                    type: 'error',
                                    buttons: ['OK'],
                                    message: 'Print command error'
                                })
                                return
                            } else {
                                dialog.showMessageBox(mainWindow, {
                                    type: 'info',
                                    buttons: ['OK'],
                                    message: 'Print command success'
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
    appWindow.setMenu(null) // Disable app menu from Electron
    if (mainWindow) { // Turn every window child of main window
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
    // Bypass certificate errors
    event.preventDefault()
    callback(true)
})
