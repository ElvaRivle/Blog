---
title: Feign - Handle both 200 and non-200 errors from response body 
description: Configuring Feign decoder and error decoder to handle all cases
date: 2024-06-30
tags:
  - Feign
  - Error handling
  - Feign (error) decoder
layout: layouts/post.njk
---
### Predstaviti problem
### Pokazati kako feign radi dekodiranje u oba slucaja
InvocationContext.java
Obicni dekoder source kod
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

Error dekoder source kod

```java
private Exception decodeError(String methodKey, Response response) {
    try {
      return errorDecoder.decode(methodKey, response);
    } finally {
      ensureClosed(response.body());
    }
  }
```

Jos jednom podcrtati problem


### Predstaviti rjesenje
napravi bazni exception (onaj server side)
napravi pojedinacne exceptione za posebne slucajeve
handling na service levelu