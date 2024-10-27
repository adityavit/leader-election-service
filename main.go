package main

import (
	"context"
	"fmt"
	"net/http"
	"os"
	"sync"
	"time"

	metav1 "k8s.io/apimachinery/pkg/apis/meta/v1"
	"k8s.io/client-go/kubernetes"
	"k8s.io/client-go/rest"
	"k8s.io/client-go/tools/leaderelection"
	"k8s.io/client-go/tools/leaderelection/resourcelock"
)

var (
	isLeader bool
	mu       sync.Mutex
)

func main() {
	// Get the pod name from the environment variable
	podName := os.Getenv("POD_NAME")
	if podName == "" {
		panic("POD_NAME environment variable not set")
	}

	// Create a Kubernetes client
	config, err := rest.InClusterConfig()
	if err != nil {
		panic(err.Error())
	}
	clientset, err := kubernetes.NewForConfig(config)
	if err != nil {
		panic(err.Error())
	}

	// Create a new resource lock
	lock := &resourcelock.LeaseLock{
		LeaseMeta: metav1.ObjectMeta{
			Name:      "http-service-lock",
			Namespace: "default",
		},
		Client: clientset.CoordinationV1(),
		LockConfig: resourcelock.ResourceLockConfig{
			Identity: podName,
		},
	}

	// Start leader election
	leaderelection.RunOrDie(context.Background(), leaderelection.LeaderElectionConfig{
		Lock:            lock,
		ReleaseOnCancel: true,
		LeaseDuration:   15 * time.Second,
		RenewDeadline:   10 * time.Second,
		RetryPeriod:     2 * time.Second,
		Callbacks: leaderelection.LeaderCallbacks{
			OnStartedLeading: func(ctx context.Context) {
				mu.Lock()
				isLeader = true
				mu.Unlock()
				startHTTPServer()
			},
			OnStoppedLeading: func() {
				mu.Lock()
				isLeader = false
				mu.Unlock()
				fmt.Printf("Leader lost: %s\n", podName)
				os.Exit(0)
			},
			OnNewLeader: func(identity string) {
				if identity == podName {
					fmt.Printf("Still the leader: %s\n", identity)
				} else {
					fmt.Printf("New leader elected: %s\n", identity)
				}
			},
		},
	})
}

func startHTTPServer() {
	http.HandleFunc("/", func(w http.ResponseWriter, r *http.Request) {
		fmt.Fprintf(w, "Hello from the leader pod!")
	})

	http.HandleFunc("/leader", func(w http.ResponseWriter, r *http.Request) {
		mu.Lock()
		defer mu.Unlock()
		if isLeader {
			w.WriteHeader(http.StatusOK)
			fmt.Fprintf(w, "true")
		} else {
			w.WriteHeader(http.StatusOK)
			fmt.Fprintf(w, "false")
		}
	})

	fmt.Println("Starting HTTP server on :8080")
	if err := http.ListenAndServe(":8080", nil); err != nil {
		fmt.Printf("Error starting HTTP server: %v\n", err)
		panic(err)
	}
}
