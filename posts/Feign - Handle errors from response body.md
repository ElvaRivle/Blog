---
title: Feign - Handle errors from response body
description: Configuring Feign decoder and error decoder to parse response body from 200 and non-200 response codes
date: 2024-06-30
tags:
  - feign
  - error handling
  - feign decoder
  - feign error decoder
layout: layouts/post.njk
---
# What's the issue?

It's time for you to grab the next ticket in the sprint. The ticket says:

> Configure error handling for XZY third-party API in our codebase

*"I know how to write an error decoder, this will be easy"*, you may say. You go to the XYZ documentation website and see that you need to handle about 10 possible errors. Along with that, you're greeted with a surprise: **In the case of error, all methods return the error details in the body, but some methods return 200, and some non-200 status codes**. Issue here is that error decoder, which handles non-200 status codes, and regular decoder, which handles 200 status codes, perform error handling quite differently. This blog post should provide a solution how to avoid code duplication (keep error handling logic in one place), and also catch only one exception, `FeignException`, in the service layer (and not 10 that are listed on the documentation website), all while still using both decoders. 

# How decoding works under the hood
Let's take a look at <a href="https://github.com/OpenFeign/feign/blob/master/core/src/main/java/feign/InvocationContext.java" target="_blank">InvocationContext.java</a>, where calls to both decoders are implemented, to see how they perform error handling.

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

As we can see, regular decoder error handling catches all exceptions, wraps them into `FeignException` and rethrows that, which is great, since on the service level, we can just catch this `FeignException`. But error decoder error handling is quite different, it **returns raw** exception, no wrapping, no re-throwing. So in case you create custom exceptions for each 10 possible API errors, or even if you create one single exception for all cases, and throw them/it from the error decoder, then you will have to handle both those/that error together with `FeignException` in service layer, which isn't ideal.

So, let's see the solution where all error handling logic is unified and service layer only deals with `FeignException`, nothing else.


# Solution (theory)

*Just to be clear, I'm not saying this is the only or the best solution, but the one I've come to with the best intention.*

The solution consist of the following:

1. Creating one base exception `BaseXYZApiException` that accepts either message as `String`, or cause as `Throwable`
    - If you decide to use case as `Throwable`, create custom exceptions for each of the 10 API error cases, or just some of them and reuse them
2. That base exception should extend `FeignException`
3. From regular decoder throw `BaseXYZApiException`, passing it either some custom some message, or one of the 10 custom exceptions
4. From error decoder, call regular decoder by wrapping it in `try-catch` block
5. If `catch` block catches `BaseXYZApiException`, return it from error decoder. Else call <a href="https://github.com/OpenFeign/feign/blob/master/core/src/main/java/feign/codec/ErrorDecoder.java#L102" target="_blank">default error decoder</a> provided by Feign
6. Only catch `FeignException` in service layer, not minding `BaseXYZApiException` or any of the 10 exceptions, if you created them
7. Configure Feign client appropriately

# Solution (code, Kotlin example)

1. Creating one base exception `BaseXYZApiException` that accepts either message as `String`, or cause as `Throwable`
    - If you decide to use case as `Throwable`, create custom exceptions for each of the 10 API error cases, or just some of them
2. That base exception should extend `FeignException`

```kotlin
//example for one of the 10 possible exceptions for API error
class ApiAccessDeniedException :
    RuntimeException(
        "Access denied for XZY external API",
    )

class BaseXYZApiException(
    status: Int,
    cause: Throwable,
) : FeignException(status, cause.message, cause)
```

3. From regular decoder throw `BaseXYZApiException`, passing it either some custom some message, or one of the 10 custom exceptions

```kotlin
//these codes in the response body represent different errors from the XYZ API
private const val INVALID_API_KEY = 301
private const val EXPIRED_SUBSCRIPTION = 302
private const val NO_QUERIES_AVAILABLE = 303
private const val API_ACCESS_DENIED = 304
private const val IP_ADDRESS_BLACKLISTED = 305
private const val BAD_REQUEST = 306
private const val INTERNAL_SERVER_ERROR = 500

class ResponseDecoder(objectMapper: ObjectMapper) : JacksonDecoder(objectMapper) {
    override fun decode(response: Response, type: Type): Any {
        //this decodedResponse could contain one of the codes above
        val decodedResponse = super.decode(response, type)

        //different calls to XYZ API will result in different response types
        //and they contain the error in different locations
        val error = when (decodedResponse) {
            is ResponseType1, ResponseType2 -> decodedResponse.errors.firstOrNull()
            is ResponseType3 -> decodedResponse.error
            else -> null
        }

        //now let's extract one of those base errors from the API into specific exception
        //based on code attribute that lives in error
        //7 in this real case, not 10 like in the article text
        val baseException = when (error?.code) {
            INVALID_API_KEY -> InvalidApiKeyException()
            EXPIRED_SUBSCRIPTION -> ExpiredSubscriptionException()
            NO_QUERIES_AVAILABLE -> NoQueriesAvailableException()
            API_ACCESS_DENIED -> ApiAccessDeniedException()
            IP_ADDRESS_BLACKLISTED -> IpAddressBlacklistedException()
            BAD_REQUEST -> BadRequestException()
            INTERNAL_SERVER_ERROR -> InternalErrorException()
            else -> null
        }

        //if we detected problematic code in response body, baseException will not be null, throw it!
        if (baseException != null) {
            throw BaseXYZApiException(response.status(), baseException)
        }

        //no error found = 200 response code with good body, simply return decoded body
        return decodedResponse
    }
}
```

4. From error decoder, call regular decoder by wrapping it in `try-catch` block
5. If `catch` block catches `BaseXYZApiException`, return it from error decoder

```kotlin
//we pass regular decoder to error decoder not via dependency injection, but via manual injection, due to the nature of how Feign client is configured
//more about that in step 7.
class ResponseErrorDecoder(private val regularDecoder: ResponseDecoder) : ErrorDecoder {
    //list of problematic HTTP status codes that should be mentioned in XYZ API documentation
    //by problematic, I mean status codes where body contains true reason behind the error
    //multiple errors could map to 400 response code for example 
    private val problematicStatusCodes = listOf(INTERNAL_SERVER_ERROR_500, FORBIDDEN_403, BAD_REQUEST_400)

    //create default error decoder provided by Feign
    //in case that regular decoder doesn't throw any BaseXZYApiException, we will use this one
    private val defaultErrorDecoder = ErrorDecoder.Default()

    override fun decode(methodKey: String, response: Response): Exception {
        val status = response.status()

        return when (status) {
            //handle non-problematic status codes before any problematic ones
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
                //if regular decoder doesn't return any exception
                //or returns one that isn't BaseXYZApiException
                //fallback to default error decoder, which again returns FeignException 
                getExceptionFromBody(response)
                    ?: defaultErrorDecoder.decode(methodKey, response)
            }
        }
    }

    //Error decoder here calls regular decoder for non 200 responses which contain error in body
    //No duplication of regular decoder code necessary here
    //This method ONLY cares about BaseXYZApiException
    //That's why for any other case, it simply returns null
    //Any other case will be handled by default error decoder
    private fun getExceptionFromBody(response: Response): Exception? {
        if (response.status() !in problematicStatusCodes) {
            return null
        }

        return try {
            regularDecoder.decode(response, ResponseType2::class.java)
            null
        } catch (ex: BaseXYZApiException) {
            ex
        } catch (ex: Exception) {
            null
        }
    }
}
```

6. Only catch `FeignException` in service layer, not minding `BaseXYZApiException` or any of the 10 exceptions, if you created them

```kotlin
try {
  val clientCallResponse = this.xyzClient.someMethod()
  //... do something with the proper response
} catch (ex: FeignException) {
  logger.error(ex) { "XYZ API call failed" }
  throw SomeNiceClientFacingError()
}
```

7. Configure Feign client appropriately

```kotlin
fun build(): XYZClient {
    //everything is instantiated manually here (Kotlin + Guava)
    //that's why passing regular decoder to error decoder is not done via dependency injection
    //in the case of Spring beans, or any other automatically instantiated and controlled object
    //injection could be done via DI
    val regularDecoder = ResponseDecoder(objectMapper)
    return Feign
        .builder()
        .decoder(regularDecoder)
        .errorDecoder(ResponseErrorDecoder(regularDecoder))
        .retryer(XYZApiRetryer())
        ...
        .target(target)
}
```