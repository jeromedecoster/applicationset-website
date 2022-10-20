const debug = require('debug')('website')
const FormData = require('form-data')
const nunjucks = require('nunjucks')
const express = require('express')
const multer = require('multer')
const axios = require('axios').default


for (var name of ['NODE_ENV', 'WEBSITE_PORT', 'CONVERT_HOST', 'CONVERT_PORT', 'STORAGE_HOST', 'STORAGE_PORT']) {
    if (process.env[name] == null || process.env[name].length == 0) { 
        throw new Error(`${name} environment variable is required`)
    }
    console.log(`process.env.${name}: ${process.env[name]}`)
}

const WEBSITE_PORT = process.env.WEBSITE_PORT
const CONVERT_HOST = process.env.CONVERT_HOST
const CONVERT_PORT = process.env.CONVERT_PORT
const STORAGE_HOST = process.env.STORAGE_HOST
const STORAGE_PORT = process.env.STORAGE_PORT

const app = express()

nunjucks.configure("views", {
    express: app,
    autoescape: false,
    noCache: true
})

app.set('view engine', 'njk')

const upload = multer({ storage: multer.memoryStorage() })

app.get('/', async (req, res) => {

    try {
        debug(`http://${STORAGE_HOST}:${STORAGE_PORT}/photos`)
        const result = await axios.get(`http://${STORAGE_HOST}:${STORAGE_PORT}/photos`)
        debug('GET / result:', result.data)
        return res.render('index', {files:result.data} )

    } catch (err) {
        debug('GET / err:', err)
        return res.status(400).send(err.message)
    }
    
})

const getFormData = (buffer, filename) => {
    const fd = new FormData()
    // https://stackoverflow.com/a/43914175
    fd.append('file', buffer, filename)
    return fd
}

app.post('/upload', upload.single('file'), async (req, res) => {
    try {

        let body = getFormData(req.file.buffer, req.file.originalname)
        // debug('POST /greyscale body:', body)
        let image = await axios.post(`http://${CONVERT_HOST}:${CONVERT_PORT}/greyscale`, body, {
            // important : https://stackoverflow.com/a/61543936
            // /!\ so many time lost without this single line below
            responseType: 'arraybuffer',
            headers: body.getHeaders()
        })
        // debug('POST /greyscale result image.config:', image.config)

        data = getFormData(image.data, req.file.originalname)

        let result = await axios.post(`http://${STORAGE_HOST}:${STORAGE_PORT}/upload`, data, {
            headers: data.getHeaders()
        })
        debug('POST /upload result image.config:', result.config)

        res.redirect('/')

    } catch (err) {
        return res.status(400).send(err.message)
    }
})

app.listen(WEBSITE_PORT, () => { 
    console.log(`Listening on port ${WEBSITE_PORT}`) 
})