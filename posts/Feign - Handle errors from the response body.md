---
title: Feign - Handle errors from the response body
description: Configuring Feign decoder and error decoder to parse response body from 200 and non-200 response codes
date: 2024-06-30
tags:
  - feign
  - error handling
  - feign decoder
  - feign error decoder
layout: layouts/post.njk
---
# Devil is in the details

It's time for you to grab the next ticket from the board. The ticket says:

> Configure Feign error handling for XZY third-party API in the codebase

*"I know how to write an error decoder, this will be easy"*, you may say. You go to the XYZ documentation website and see that you need to handle about 10 possible errors. Along with that, you're greeted with a surprise: **In the case of error, all methods return the error details in the body, but some methods return 200, and some non-200 status codes**. Issue here is that error decoder, which handles non-200 status codes, and regular decoder, which handles 200 status codes, perform error handling quite differently. This blog post should provide a solution on how to avoid code duplication (keep error handling logic in one place), and also catch only one exception, `FeignException`, in the service layer (and not 10 that are listed on the documentation website), all while still using both decoders. 

### Example

<a href="https://iban.com" target="_blank">iban.com</a> is the perfect example of this behavior. It's function is validating bank account information and fetching bank details. For every validation error, the reason behind the error is provided in the response body. <a href="https://www.iban.com/validation-api" target="_blank">But for the case of IBAN validation, HTTP response code is 200</a> (not explicitly mentioned in the docs), <a href="https://www.iban.com/bic-validation-api" target="_blank">while in the case of BIC validation, HTTP response code is non-200</a>.

# How decoding error handling works under the hood
Let's take a look at <a href="https://github.com/OpenFeign/feign/blob/master/core/src/main/java/feign/InvocationContext.java" target="_blank">InvocationContext.java</a> from Feign library, where calls to both decoders are implemented, to see how they perform error handling.

Regular decoder call source code:

```java
private Object decode(Response response, Type returnType) {
    try {
      return decoder.decode(response, returnType);
    } catch (final FeignException e) {
      throw e;
    } catch (final RuntimeException e) {
      throw new DecodeException(response.status(), e.getMessage(), response.request(), e);
    } catch (IOException e) {
      throw errorReading(response.request(), response, e);
    }
  }
```

Error decoder call source code:

```java
private Exception decodeError(String methodKey, Response response) {
    try {
      return errorDecoder.decode(methodKey, response);
    } finally {
      ensureClosed(response.body());
    }
  }
```

As we can see, regular decoder error handling catches all exceptions, wraps them into `FeignException` and rethrows that, which is great, since on the service level, we can just catch this `FeignException`. But error decoder error handling is quite different, it **returns raw** exception, no wrapping, no re-throwing. So in the case you create custom exceptions for all 10 possible API errors, or even if you create one single exception for all cases, and throw them/it from the error decoder, then you will have to handle both those/that error together with `FeignException` in service layer, which isn't ideal.

So, let's see the solution where all error handling logic is unified and service layer only deals with the `FeignException`, nothing else.

# Solution (theory)

*Just to be clear, I'm not saying this is the only or the best solution, but the one I've come to with the best intention.*

The solution consist of the following:

1. Create one base exception `BaseXYZApiException` that accepts either message as `String`, or cause as `Throwable`
    - If you decide to use cause as `Throwable`, create custom exceptions for each of the 10 API error cases
2. That base exception should extend `FeignException`
3. From regular decoder throw `BaseXYZApiException`, passing it either some custom message, or one of the 10 custom exceptions as cause
4. From error decoder, call regular decoder by wrapping the call in `try-catch` block
5. If `catch` block catches `BaseXYZApiException`, return it from error decoder. Otherwise, call <a href="https://github.com/OpenFeign/feign/blob/master/core/src/main/java/feign/codec/ErrorDecoder.java#L102" target="_blank">default error decoder</a> provided by Feign
    - This default error decoder will return `FeignException` for all cases
6. Only catch `FeignException` in service layer, not minding `BaseXYZApiException` or any of the 10 exceptions
7. Configure Feign client appropriately

# We covered all possible scenarios

Let's examine all possible cases which can happen and how we covered them with the provided solution:

1. 200 response code without error in the body &rarr; regular decoder will be called and no exception will be thrown, our service layer will receive decoded response object, the happiest path possible
```json
{
    "data": {
        ...
    },
    "error": {},
}
```
2. 200 response code with error in the body &rarr; regular decoder will be called and our custom made exception will be thrown (`BaseXYZApiException` mentioned earlier), which will be handled by our service layer as `FeignException`
```json
{
    "_comment": "HTTP response code for this response is 200",
    "data": {
        ...
    },
    "error": {
        "code": 301,
        "message": "Error message"
    }
}
```
3. non-200 response code with or without error in the body &rarr; error decoder will be called
	1. First handle all response codes where error wouldn't be in the body per XYZ API docs. Example in our case can be 429, Too Many Requests, where body is completely empty
    2. If response code is one where error could be in the body per XYZ API docs, call the regular decoder to extract proper exception from it, then return that exception
    3. If regular decoder from the previous step doesn't throw `BaseXYZApiException`, then some other error has happened which we will leave to default Feign error decoder to handle
    4. Any exception returned from the error decoder will be handled by our service layer as `FeignException`
```json
{
    "_comment": "HTTP response code for this response is non-200",
    "data": {
        ...
    },
    "error": {
        "code": 301,
        "message": "Error message"
    }
}
```

# Solution (code, Kotlin example)

1. Create one base exception `BaseXYZApiException` that accepts either message as `String`, or cause as `Throwable`
    - If you decide to use cause as `Throwable`, create custom exceptions for each of the 10 API error cases
2. That base exception should extend `FeignException`

```kotlin
//example for one of the 10 possible exceptions for API error
class InvalidApiKeyException :
    RuntimeException(
        "Invalid API key for XZY external API",
    )

//this example will use cause as Throwable
class BaseXYZApiException(
    status: Int,
    cause: Throwable,
) : FeignException(status, cause.message, cause)
```

3. From regular decoder throw `BaseXYZApiException`, passing it either some custom message, or one of the 10 custom exceptions as cause

```kotlin
private const val INVALID_API_KEY = 301
private const val EXPIRED_SUBSCRIPTION = 302
...

class ResponseDecoder(objectMapper: ObjectMapper) : JacksonDecoder(objectMapper) {
    override fun decode(response: Response, type: Type): Any {
        val decodedResponse = super.decode(response, type)
		val error = decodedResponse.error

        //error object contains code attribute
        //based on which we determine which exception should be thrown
        val baseException = when (error?.code) {
            INVALID_API_KEY -> InvalidApiKeyException()
            EXPIRED_SUBSCRIPTION -> ExpiredSubscriptionException()
            ...
            else -> null
        }

        if (baseException != null) {
	        //passing baseException defined above to BaseXYZApiException
            throw BaseXYZApiException(response.status(), baseException)
        }

        //no error found in response, the happiest path
        return decodedResponse
    }
}
```

4. From error decoder, call regular decoder by wrapping it in `try-catch` block
5. If `catch` block catches `BaseXYZApiException`, return it from error decoder. Otherwise, call <a href="https://github.com/OpenFeign/feign/blob/master/core/src/main/java/feign/codec/ErrorDecoder.java#L102" target="_blank">default error decoder</a> provided by Feign
    - This default error decoder will return `FeignException` for all cases

```kotlin
class ResponseErrorDecoder(private val regularDecoder: ResponseDecoder) : ErrorDecoder {
    private val statusCodesWhereBodyCouldContainError = listOf(INTERNAL_SERVER_ERROR_500, FORBIDDEN_403, BAD_REQUEST_400)

    //create default error decoder provided by Feign
    private val defaultErrorDecoder = ErrorDecoder.Default()

    override fun decode(methodKey: String, response: Response): Exception {
        val status = response.status()

        return when (status) {
			//first handle all response codes where body wouldn't contain an error
            TOO_MANY_REQUESTS_429 -> {
                RetryableException(
                    response.status(),
                    response.reason(),
                    response.request().httpMethod(),
                    null as Long?,
                    response.request(),
                )
            }
            else -> {
                //if regular decoder doesn't return BaseXYZApiException
                //fallback to default error decoder
                getExceptionFromBody(response)
                    ?: defaultErrorDecoder.decode(methodKey, response)
            }
        }
    }
    
    private fun getExceptionFromBody(response: Response): Exception? {
        //response code for which parsing the body isn't necessary
        if (response.status() !in statusCodesWhereBodyCouldContainError) {
            return null
        }

        return try {
            regularDecoder.decode(response, ResponseType2::class.java)
            //no error in body found
            null
        } catch (ex: BaseXYZApiException) {
	        //body contains error and regular decoder threw BaseXYZApiException
            ex
        } catch (ex: Exception) {
	        //we can ignore exceptions that aren't BaseXYZApiException
	        //Feign default error decoder will handle them properly
            null
        }
    }
}
```

6. Only catch `FeignException` in service layer, not minding `BaseXYZApiException` or any of the 10 exceptions

```kotlin
try {
  val clientCallResponse = this.xyzClient.someMethod()
  //the happiest path
  //do something with the proper response here
} catch (ex: FeignException) {
  //we don't lose information about what has caused FeignException since we provided the cause to the BaseXYZApiException
  logger.error(ex) { "XYZ API call failed" }
  throw SomeNiceClientFacingError()
}
```

7. Configure Feign client appropriately

```kotlin
fun build(): XYZClient {
    val regularDecoder = ResponseDecoder(objectMapper)
    return Feign
        .builder()
        .decoder(regularDecoder)
        .errorDecoder(ResponseErrorDecoder(regularDecoder))
        ...
        .target(target)
}
```