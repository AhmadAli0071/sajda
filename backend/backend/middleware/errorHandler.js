const errorHandler = (err, req, res, next) => {
  let statusCode = res.statusCode === 200 ? 500 : res.statusCode;
  let message = err.message;

  if (err.name === 'CastError' && err.kind === 'ObjectId') {
    statusCode = 404;
    message = 'Resource not found';
  }

  if (err.code === 11000) {
    statusCode = 400;
    const field = Object.keys(err.keyValue)[0];
    message = `Duplicate value for ${field}`;
  }

  if (err.name === 'ValidationError') {
    statusCode = 400;
    message = Object.values(err.errors).map(e => e.message).join(', ');
  }

  if (err.name === 'JsonWebTokenError') {
    statusCode = 401;
    message = 'Invalid token';
  }

  if (err.name === 'TokenExpiredError') {
    statusCode = 401;
    message = 'Token expired';
  }

  // body-parser errors. A malformed JSON body is a CLIENT mistake — it used
  // to fall through as a 500 (and the Flutter client showed "server error").
  if (err.type === 'entity.parse.failed') {
    statusCode = 400;
    message = 'Invalid JSON in request body';
  } else if (err.type === 'entity.too.large') {
    statusCode = 413;
    message = 'Request body too large';
  }

  // Machine-readable code — the app branches on `code`, never on message
  // text (ApiException.code). Only a STRING err.code is passed through:
  // mongoose/body-parser use numerics there (11000 etc.).
  let code;
  if (typeof err.code === 'string') {
    code = err.code;
  } else {
    code =
      statusCode === 400 ? 'VALIDATION' :
      statusCode === 401 ? 'UNAUTHORIZED' :
      statusCode === 404 ? 'NOT_FOUND' :
      statusCode === 413 ? 'PAYLOAD_TOO_LARGE' :
      statusCode === 429 ? 'RATE_LIMITED' :
      statusCode >= 500 ? 'SERVER_ERROR' : undefined;
  }

  res.status(statusCode).json({
    success: false,
    message,
    ...(code ? { code } : {}),
    stack: process.env.NODE_ENV === 'production' ? null : err.stack,
  });
};

export default errorHandler;
