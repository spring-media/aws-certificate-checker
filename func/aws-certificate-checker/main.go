package main

import (
	"context"
	"fmt"

	"github.com/aws/aws-lambda-go/lambdacontext"

	"github.com/aws/aws-lambda-go/lambda"
)

func main() {
	lambda.Start(handler)
}

func handler(ctx context.Context) error {
	lc, _ := lambdacontext.FromContext(ctx)
	fmt.Printf("Hello %sn\n", lc.AwsRequestID)
	return nil
}
