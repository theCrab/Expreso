// httpCodes.ts
export interface IHttpCode {
    code: string;
    message: string;
    status: number;
}

export const HttpCodes = {
    BAD_REQUEST: {
        code: "BAD_REQUEST",
        message: "The request cannot be fulfilled due to bad syntax or invalid parameters.",
        status: 400
    },
    NOT_FOUND: {
        code: "NOT_FOUND",
        message: "The requested resource could not be found.",
        status: 404
    },
    VALIDATION_ERROR: {
        code: "VALIDATION_ERROR",
        message: "The provided payload failed validation checks.",
        status: 422
    },
    INTERNAL_SERVER_ERROR: {
        code: "INTERNAL_SERVER_ERROR",
        message: "An internal server error occurred while processing the request.",
        status: 500
    }
} as const;

export type HttpCode = (typeof HttpCodes)[keyof typeof HttpCodes];
